import Foundation

/// Resolves device hostnames using DNS PTR lookup and Bonjour service matching.
/// Runs entirely off MainActor to avoid UI thread blocking.
final class DeviceNameResolver: Sendable {

    /// Resolve a single device hostname using DNS PTR lookup and Bonjour services
    /// - Parameters:
    ///   - ipAddress: The IP address to resolve
    ///   - bonjourServices: Available Bonjour services to match against
    /// - Returns: Resolved hostname or nil if not found
    func resolve(ipAddress: String, bonjourServices: [BonjourService]) async -> String? {
        // Try DNS PTR lookup first (with 3s timeout)
        if let ptrName = await resolvePTRWithTimeout(ipAddress: ipAddress) {
            return ptrName
        }

        // Fall back to Bonjour service matching
        return matchBonjourService(ipAddress: ipAddress, services: bonjourServices)
    }

    /// Resolve multiple devices concurrently
    /// - Parameters:
    ///   - devices: Array of tuples containing IP address and MAC address
    ///   - bonjourServices: Available Bonjour services to match against
    /// - Returns: Dictionary mapping IP addresses to resolved names
    func resolveAll(
        devices: [(ipAddress: String, macAddress: String)],
        bonjourServices: [BonjourService]
    ) async -> [String: String] {
        var results: [String: String] = [:]

        await withTaskGroup(of: (String, String?).self) { group in
            for device in devices {
                group.addTask {
                    let name = await self.resolve(ipAddress: device.ipAddress, bonjourServices: bonjourServices)
                    return (device.ipAddress, name)
                }
            }

            for await (ip, name) in group {
                if let name = name {
                    results[ip] = name
                }
            }
        }

        return results
    }

    // MARK: - Private Helpers

    /// Perform DNS PTR lookup with a 3-second timeout
    private func resolvePTRWithTimeout(ipAddress: String) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                await self.performPTRLookup(ipAddress: ipAddress)
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
                return nil
            }
            let result = await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }

    /// Perform the actual PTR lookup using getnameinfo on a background thread.
    /// This avoids the complex DNSServiceQueryRecord callback chain and runs
    /// entirely off MainActor.
    private func performPTRLookup(ipAddress: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)

                guard inet_pton(AF_INET, ipAddress, &addr.sin_addr) == 1 else {
                    continuation.resume(returning: nil)
                    return
                }

                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                let result = withUnsafePointer(to: &addr) { addrPtr in
                    addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                        getnameinfo(
                            sockaddrPtr,
                            socklen_t(MemoryLayout<sockaddr_in>.size),
                            &hostname,
                            socklen_t(hostname.count),
                            nil, 0,
                            0
                        )
                    }
                }

                if result == 0 {
                    let name = hostname.withUnsafeBufferPointer { buffer in
                        let count = buffer.firstIndex(of: 0) ?? buffer.count
                        return buffer.prefix(count).withUnsafeBytes { bytes in
                            String(decoding: bytes, as: UTF8.self)
                        }
                    }
                    // getnameinfo returns the IP itself if no reverse DNS exists
                    if name != ipAddress && !name.isEmpty {
                        continuation.resume(returning: name)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Match IP address against Bonjour services
    private func matchBonjourService(ipAddress: String, services: [BonjourService]) -> String? {
        for service in services {
            if service.addresses.contains(ipAddress) {
                return service.hostName ?? service.name
            }
        }
        return nil
    }
}
