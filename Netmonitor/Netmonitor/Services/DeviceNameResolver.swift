import Foundation

@MainActor
final class DeviceNameResolver {
    private(set) var isResolving: Bool = false
    private let dnsService = DNSLookupService()

    /// Resolve a single device hostname using DNS PTR lookup and Bonjour services
    /// - Parameters:
    ///   - ipAddress: The IP address to resolve
    ///   - bonjourServices: Available Bonjour services to match against
    /// - Returns: Resolved hostname or nil if not found
    func resolve(ipAddress: String, bonjourServices: [BonjourService]) async -> String? {
        // Try DNS PTR lookup first
        if let ptrName = await resolvePTR(ipAddress: ipAddress) {
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
        isResolving = true
        defer { isResolving = false }

        var results: [String: String] = [:]
        let maxConcurrency = 10
        var currentCount = 0

        await withTaskGroup(of: (String, String?).self) { group in
            for device in devices {
                // Wait if we've reached max concurrency
                while currentCount >= maxConcurrency {
                    if let (ip, name) = await group.next() {
                        if let name = name {
                            results[ip] = name
                        }
                        currentCount -= 1
                    }
                }

                currentCount += 1
                group.addTask {
                    let name = await self.resolve(ipAddress: device.ipAddress, bonjourServices: bonjourServices)
                    return (device.ipAddress, name)
                }
            }

            // Collect remaining results
            for await (ip, name) in group {
                if let name = name {
                    results[ip] = name
                }
            }
        }

        return results
    }

    // MARK: - Private Helpers

    /// Perform DNS PTR lookup for an IP address
    private func resolvePTR(ipAddress: String) async -> String? {
        // Construct PTR domain by reversing IP octets
        guard let ptrDomain = constructPTRDomain(ipAddress: ipAddress) else {
            return nil
        }

        // Query PTR record using DNSLookupService
        guard let result = await dnsService.lookup(domain: ptrDomain, recordType: .ptr) else {
            return nil
        }

        // Extract hostname from PTR records
        guard let ptrRecord = result.records.first else {
            return nil
        }

        // Strip trailing dot from PTR result if present
        var hostname = ptrRecord.value
        if hostname.hasSuffix(".") {
            hostname.removeLast()
        }

        return hostname.isEmpty ? nil : hostname
    }

    /// Construct PTR domain from IP address
    /// For example: "192.168.1.1" -> "1.1.168.192.in-addr.arpa"
    private func constructPTRDomain(ipAddress: String) -> String? {
        let octets = ipAddress.split(separator: ".").map(String.init)
        guard octets.count == 4 else {
            return nil
        }

        let reversedOctets = octets.reversed().joined(separator: ".")
        return "\(reversedOctets).in-addr.arpa"
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
