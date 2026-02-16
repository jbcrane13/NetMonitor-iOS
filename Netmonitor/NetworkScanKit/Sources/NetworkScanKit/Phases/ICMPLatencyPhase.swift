import Foundation
import os.log

private let logger = Logger(subsystem: "com.netmonitor.scankit", category: "ICMPLatency")

/// Enriches already-discovered devices with ICMP-based latency measurements.
///
/// Runs after TCP/SSDP phases. For any device that was found by ARP or Bonjour
/// but has no latency, sends a single ICMP echo request. Almost all LAN devices
/// respond to ICMP, making this far more effective than TCP-only latency probes.
///
/// Falls back gracefully: if the ICMP socket can't be created (e.g. Simulator),
/// the phase completes immediately and the TCP-based enrichment in
/// ``TCPProbeScanPhase`` remains the sole latency source.
public struct ICMPLatencyPhase: ScanPhase, Sendable {
    public let id = "icmpLatency"
    public let displayName = "Measuring latency…"
    public let weight: Double = 0.10

    /// Maximum concurrent ICMP probes.
    private let maxConcurrent: Int

    /// Timeout per probe in seconds.
    private let timeout: TimeInterval

    public init(maxConcurrent: Int = 50, timeout: TimeInterval = 2.0) {
        self.maxConcurrent = maxConcurrent
        self.timeout = timeout
    }

    public func execute(
        context: ScanContext,
        accumulator: ScanAccumulator,
        onProgress: @Sendable (Double) async -> Void
    ) async {
        await onProgress(0.0)

        let ipsNeedingLatency = await accumulator.ipsWithoutLatency()
        guard !ipsNeedingLatency.isEmpty else {
            await onProgress(1.0)
            return
        }

        // Try to create an ICMP socket — fails on Simulator
        let socketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard socketFd >= 0 else {
            logger.info("ICMP socket unavailable (errno=\(errno)), skipping ICMP latency enrichment")
            await onProgress(1.0)
            return
        }

        // Set non-blocking for poll-based timeout
        let flags = fcntl(socketFd, F_GETFL, 0)
        _ = fcntl(socketFd, F_SETFL, flags | O_NONBLOCK)

        logger.info("ICMP latency enrichment: \(ipsNeedingLatency.count) devices to probe")

        let total = ipsNeedingLatency.count
        let concurrencyLimit = ThermalThrottleMonitor.shared.effectiveLimit(from: maxConcurrent)
        var probed = 0
        var enriched = 0

        // Each task gets its own socket to avoid fd contention
        // Close the test socket, tasks create their own
        close(socketFd)

        await withTaskGroup(of: (String, Double?).self) { group in
            var pending = 0
            var iterator = ipsNeedingLatency.makeIterator()

            while pending < concurrencyLimit, let ip = iterator.next() {
                pending += 1
                let probeTimeout = timeout
                group.addTask {
                    let latency = await Self.icmpProbe(ip: ip, timeout: probeTimeout)
                    return (ip, latency)
                }
            }

            while let (ip, latency) = await group.next() {
                pending -= 1
                probed += 1

                if let latency {
                    await accumulator.updateLatency(ip: ip, latency: latency)
                    enriched += 1
                }

                let progress = Double(probed) / Double(max(total, 1))
                await onProgress(progress)

                if let nextIP = iterator.next() {
                    pending += 1
                    let probeTimeout = timeout
                    group.addTask {
                        let latency = await Self.icmpProbe(ip: nextIP, timeout: probeTimeout)
                        return (nextIP, latency)
                    }
                }
            }
        }

        logger.info("ICMP latency enrichment complete: \(enriched)/\(total) devices enriched")
        await onProgress(1.0)
    }

    // MARK: - ICMP Probe (self-contained, no actor dependency)

    /// Send a single ICMP echo request and measure RTT.
    /// Returns latency in milliseconds, or nil on failure/timeout.
    private static func icmpProbe(ip: String, timeout: TimeInterval) async -> Double? {
        // Create a dedicated socket for this probe
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { return nil }

        // Build ICMP echo request
        let sequence = UInt16.random(in: 1...UInt16.max)
        let packet = buildEchoRequest(sequence: sequence)

        let startTime = ContinuousClock.now

        // Send
        let sent = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                sendto(fd, packet, packet.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard sent == packet.count else { return nil }

        // Poll for response
        let timeoutMs = Int32(timeout * 1000)
        var pollFd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let pollResult = poll(&pollFd, 1, timeoutMs)
        guard pollResult > 0 else { return nil }

        // Receive
        var buf = [UInt8](repeating: 0, count: 256)
        let received = recv(fd, &buf, buf.count, 0)
        guard received > 0 else { return nil }

        // Calculate RTT
        let elapsed = ContinuousClock.now - startTime
        let rtt = Double(elapsed.components.seconds) * 1000.0
            + Double(elapsed.components.attoseconds) / 1e15

        // Validate it's an echo reply (skip IP header if present)
        let data = Array(buf[0..<received])
        var offset = 0
        if data.count >= 20 && (data[0] >> 4) == 4 {
            offset = Int(data[0] & 0x0F) * 4
        }

        guard data.count > offset else { return nil }
        let icmpType = data[offset]

        // Type 0 = Echo Reply
        if icmpType == 0 {
            return rtt
        }

        return nil
    }

    // MARK: - Packet Building

    /// Build an ICMP echo request packet (type 8, code 0).
    private static func buildEchoRequest(sequence: UInt16, payloadSize: Int = 16) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: 8 + payloadSize)

        // Type 8 (Echo Request), Code 0
        packet[0] = 8
        packet[1] = 0

        // Identifier (use pid)
        let ident = UInt16(ProcessInfo.processInfo.processIdentifier & 0xFFFF)
        packet[4] = UInt8(ident >> 8)
        packet[5] = UInt8(ident & 0xFF)

        // Sequence number
        packet[6] = UInt8(sequence >> 8)
        packet[7] = UInt8(sequence & 0xFF)

        // Payload
        for i in 0..<payloadSize {
            packet[8 + i] = UInt8(i & 0xFF)
        }

        // Checksum (RFC 1071)
        let checksum = internetChecksum(packet)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)

        return packet
    }

    /// RFC 1071 Internet Checksum.
    private static func internetChecksum(_ data: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        while i < data.count - 1 {
            sum += UInt32(data[i]) << 8 | UInt32(data[i + 1])
            i += 2
        }
        if i < data.count {
            sum += UInt32(data[i]) << 8
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return ~UInt16(sum)
    }
}
