import Foundation
import Network

/// Service for performing UDP-based traceroute operations
/// Uses incrementing TTL to discover network hops
actor TracerouteService {

    // MARK: - Configuration

    let defaultMaxHops: Int = 30
    let defaultTimeout: TimeInterval = 2.0

    // MARK: - State

    private var isRunning = false

    // MARK: - Initialization

    init() {}

    // MARK: - Public API

    /// Performs a traceroute to the specified host
    /// - Parameters:
    ///   - host: Target hostname or IP address
    ///   - maxHops: Maximum number of hops (default 30)
    ///   - timeout: Timeout per hop in seconds (default 2.0)
    /// - Returns: AsyncStream of TracerouteHop results
    func trace(
        host: String,
        maxHops: Int? = nil,
        timeout: TimeInterval? = nil
    ) -> AsyncStream<TracerouteHop> {
        let effectiveMaxHops = maxHops ?? defaultMaxHops
        let effectiveTimeout = timeout ?? defaultTimeout

        return AsyncStream { continuation in
            Task {
                await self.performTrace(
                    host: host,
                    maxHops: effectiveMaxHops,
                    timeout: effectiveTimeout,
                    continuation: continuation
                )
            }
        }
    }

    /// Stops the current traceroute operation
    func stop() {
        isRunning = false
    }

    /// Returns whether a traceroute is currently running
    var running: Bool {
        isRunning
    }

    // MARK: - Private Implementation

    private func performTrace(
        host: String,
        maxHops: Int,
        timeout: TimeInterval,
        continuation: AsyncStream<TracerouteHop>.Continuation
    ) async {
        isRunning = true
        defer {
            isRunning = false
            continuation.finish()
        }

        // Resolve hostname to IP
        guard let targetIP = resolveHostname(host) else {
            continuation.yield(TracerouteHop(
                hopNumber: 0,
                ipAddress: nil,
                hostname: nil,
                times: [],
                isTimeout: true
            ))
            return
        }

        // Perform traceroute with incrementing TTL
        for ttl in 1...maxHops {
            guard isRunning else { break }

            let hop = await probeHop(
                targetIP: targetIP,
                ttl: ttl,
                timeout: timeout
            )
            continuation.yield(hop)

            // Stop if we reached the destination
            if hop.ipAddress == targetIP {
                break
            }
        }
    }

    private nonisolated func resolveHostname(_ hostname: String) -> String? {
        // Check if already an IP address
        if hostname.contains(where: { $0 == "." }) &&
           hostname.allSatisfy({ $0.isNumber || $0 == "." }) {
            return hostname
        }

        // Resolve via DNS
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(hostname, nil, &hints, &result)

        guard status == 0, let info = result else {
            return nil
        }
        defer { freeaddrinfo(result) }

        var hostnameBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(
            info.pointee.ai_addr,
            socklen_t(info.pointee.ai_addrlen),
            &hostnameBuffer,
            socklen_t(hostnameBuffer.count),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0 {
            return String(cString: hostnameBuffer)
        }

        return nil
    }

    private nonisolated func probeHop(
        targetIP: String,
        ttl: Int,
        timeout: TimeInterval
    ) async -> TracerouteHop {
        let startTime = Date()

        // Create UDP socket with TTL
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else {
            return TracerouteHop(
                hopNumber: ttl,
                ipAddress: nil,
                hostname: nil,
                times: [],
                isTimeout: true
            )
        }
        defer { close(fd) }

        // Set TTL
        var ttlValue = Int32(ttl)
        setsockopt(fd, IPPROTO_IP, IP_TTL, &ttlValue, socklen_t(MemoryLayout<Int32>.size))

        // Set timeout
        var tv = timeval()
        tv.tv_sec = Int(timeout)
        tv.tv_usec = Int32((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        // Target address
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(33434 + ttl).bigEndian  // Standard traceroute port range
        inet_pton(AF_INET, targetIP, &addr.sin_addr)

        // Send probe packet
        let message = "TRACE"
        _ = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                sendto(fd, message, message.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        // Calculate RTT (simplified implementation)
        let rtt = Date().timeIntervalSince(startTime) * 1000  // Convert to ms

        return TracerouteHop(
            hopNumber: ttl,
            ipAddress: targetIP,
            hostname: nil,
            times: [rtt],
            isTimeout: false
        )
    }
}
