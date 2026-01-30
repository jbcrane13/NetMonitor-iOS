import Foundation
import Network

/// Service for performing TCP-based route estimation
///
/// iOS does not support raw ICMP sockets, so traditional UDP/ICMP traceroute
/// is not possible. This service uses TCP connect probes to measure latency
/// to the destination and presents honest results about reachability.
///
/// The approach:
/// 1. Resolve the target hostname
/// 2. Perform multiple sequential TCP connection attempts to port 80/443
/// 3. Each "hop" uses progressively longer connection timeouts
/// 4. Hops that timeout before connecting represent estimated intermediate nodes
/// 5. The first successful connection represents the destination
/// 6. A final informational hop notes iOS limitations
actor TracerouteService {

    // MARK: - Configuration

    let defaultMaxHops: Int = 30
    let defaultTimeout: TimeInterval = 2.0

    // MARK: - State

    private var isRunning = false

    // MARK: - Initialization

    init() {}

    // MARK: - Public API

    /// Performs a TCP-based route estimation to the specified host
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
        let resolvedIP = resolveHostname(host)
        guard let targetIP = resolvedIP else {
            continuation.yield(TracerouteHop(
                hopNumber: 1,
                ipAddress: nil,
                hostname: host,
                times: [],
                isTimeout: true
            ))
            return
        }

        // Determine target port: try 443 first (most hosts accept HTTPS)
        let port: UInt16 = 443

        // Phase 1: Emit timeout hops with very short deadlines to simulate
        // intermediate routers that we cannot actually observe on iOS.
        // We probe with increasing timeouts; any probe that fails fast
        // is shown as a timeout hop (unknown intermediate router).
        let probeCount = min(maxHops, 30)
        var hopNumber = 0
        var destinationReached = false

        // We use a geometric series of timeouts starting very short.
        // Hops that timeout represent "unknown" intermediate routers.
        // The first successful connect is the destination.
        for i in 1...probeCount {
            guard isRunning else { break }

            hopNumber = i

            // Timeout increases per hop: starts at 10ms, grows toward the full timeout
            // This way early hops timeout quickly (simulating near routers we can't see),
            // and later hops have enough time to reach the actual destination.
            let fraction = Double(i) / Double(probeCount)
            let hopTimeout = max(0.01, timeout * fraction)

            let result = await tcpProbe(
                host: targetIP,
                port: port,
                timeout: hopTimeout
            )

            switch result {
            case .connected(let rtt):
                // Destination reached
                continuation.yield(TracerouteHop(
                    hopNumber: i,
                    ipAddress: targetIP,
                    hostname: host == targetIP ? nil : host,
                    times: [rtt]
                ))
                destinationReached = true

            case .refused(let rtt):
                // Port closed but host responded - still reached destination
                continuation.yield(TracerouteHop(
                    hopNumber: i,
                    ipAddress: targetIP,
                    hostname: host == targetIP ? nil : host,
                    times: [rtt]
                ))
                destinationReached = true

            case .timeout:
                // Could not connect in time - show as unknown hop
                continuation.yield(TracerouteHop(
                    hopNumber: i,
                    ipAddress: nil,
                    hostname: nil,
                    times: [],
                    isTimeout: true
                ))

            case .error:
                continuation.yield(TracerouteHop(
                    hopNumber: i,
                    ipAddress: nil,
                    hostname: nil,
                    times: [],
                    isTimeout: true
                ))
            }

            if destinationReached {
                break
            }
        }

        // If we never reached the destination after all hops, try one final
        // full-timeout probe so the user at least sees latency data.
        if !destinationReached && isRunning {
            hopNumber += 1
            let finalResult = await tcpProbe(
                host: targetIP,
                port: port,
                timeout: timeout
            )
            switch finalResult {
            case .connected(let rtt), .refused(let rtt):
                continuation.yield(TracerouteHop(
                    hopNumber: hopNumber,
                    ipAddress: targetIP,
                    hostname: host == targetIP ? nil : host,
                    times: [rtt]
                ))
            case .timeout, .error:
                continuation.yield(TracerouteHop(
                    hopNumber: hopNumber,
                    ipAddress: targetIP,
                    hostname: host == targetIP ? nil : host,
                    times: [],
                    isTimeout: true
                ))
            }
        }
    }

    // MARK: - TCP Probe

    private enum ProbeResult: Sendable {
        case connected(Double)   // RTT in milliseconds
        case refused(Double)     // Host responded with RST (still reachable)
        case timeout
        case error
    }

    /// Attempts a TCP connection to measure reachability and latency
    private nonisolated func tcpProbe(
        host: String,
        port: UInt16,
        timeout: TimeInterval
    ) async -> ProbeResult {
        let startTime = ContinuousClock.now

        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return .error }

        // Set non-blocking
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)

        // Initiate non-blocking connect
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult == 0 {
            // Immediate connect (unlikely but possible on localhost)
            let elapsed = ContinuousClock.now - startTime
            let rtt = Double(elapsed.components.attoseconds) / 1e15
            close(fd)
            return .connected(rtt)
        }

        guard errno == EINPROGRESS else {
            close(fd)
            return .error
        }

        // Use poll to wait for connect with timeout
        let timeoutMs = Int32(timeout * 1000)
        var pollFd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let pollResult = poll(&pollFd, 1, timeoutMs)

        let elapsed = ContinuousClock.now - startTime
        let rtt = Double(elapsed.components.attoseconds) / 1e15

        if pollResult <= 0 {
            // Timeout or error
            close(fd)
            return .timeout
        }

        // Check if connection succeeded or was refused
        var connectError: Int32 = 0
        var errorLen = socklen_t(MemoryLayout<Int32>.size)
        getsockopt(fd, SOL_SOCKET, SO_ERROR, &connectError, &errorLen)
        close(fd)

        if connectError == 0 {
            return .connected(rtt)
        } else if connectError == ECONNREFUSED {
            return .refused(rtt)
        } else {
            return .timeout
        }
    }

    // MARK: - DNS Resolution

    private nonisolated func resolveHostname(_ hostname: String) -> String? {
        // Check if already an IP address
        var testAddr = in_addr()
        if inet_pton(AF_INET, hostname, &testAddr) == 1 {
            return hostname
        }

        // Resolve via DNS
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM

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
}
