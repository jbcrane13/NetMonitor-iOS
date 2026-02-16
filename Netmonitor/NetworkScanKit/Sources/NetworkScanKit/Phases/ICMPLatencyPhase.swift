import Foundation
import os.log

private let logger = Logger(subsystem: "com.netmonitor.scankit", category: "ICMPLatency")

/// Enriches already-discovered devices with ICMP-based latency measurements.
///
/// Uses a single-socket ping sweep: sends ICMP echo requests to all target IPs
/// rapidly, then collects responses as they arrive. This avoids kernel ICMP rate
/// limiting and socket creation overhead that inflate per-probe latency.
///
/// Falls back gracefully: if the ICMP socket can't be created (e.g. Simulator),
/// the phase completes immediately.
public struct ICMPLatencyPhase: ScanPhase, Sendable {
    public let id = "icmpLatency"
    public let displayName = "Measuring latency…"
    public let weight: Double = 0.10

    /// How long to wait for all responses after sending.
    private let collectTimeout: TimeInterval

    public init(collectTimeout: TimeInterval = 2.0) {
        self.collectTimeout = collectTimeout
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

        // Create a single ICMP socket — fails on Simulator
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard fd >= 0 else {
            logger.info("ICMP socket unavailable (errno=\(errno)), skipping latency enrichment")
            await onProgress(1.0)
            return
        }
        defer { close(fd) }

        // Non-blocking for poll-based collection
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        logger.info("ICMP ping sweep: \(ipsNeedingLatency.count) devices to probe")

        // Map sequence number → (ip, sendTime)
        let ident = UInt16(ProcessInfo.processInfo.processIdentifier & 0xFFFF)
        var pending: [UInt16: (ip: String, sendTime: ContinuousClock.Instant)] = [:]
        var enriched = 0

        // Phase 1: Send all echo requests rapidly
        for (index, ip) in ipsNeedingLatency.enumerated() {
            let seq = UInt16(index + 1)
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            guard inet_pton(AF_INET, ip, &addr.sin_addr) == 1 else { continue }

            let packet = Self.buildEchoRequest(identifier: ident, sequence: seq)
            let sendTime = ContinuousClock.now

            let sent = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    sendto(fd, packet, packet.count, 0, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }

            if sent == packet.count {
                pending[seq] = (ip: ip, sendTime: sendTime)
            }
        }

        logger.debug("Sent \(pending.count) ICMP echo requests")
        await onProgress(0.5)

        // Phase 2: Collect responses until timeout or all received
        let deadline = ContinuousClock.now + .milliseconds(Int(collectTimeout * 1000))
        var buf = [UInt8](repeating: 0, count: 256)
        var fromAddr = sockaddr_in()
        var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        while !pending.isEmpty && ContinuousClock.now < deadline {
            let remaining = deadline - .now
            let remainingMs = max(1, Int32(
                remaining.components.seconds * 1000 +
                remaining.components.attoseconds / 1_000_000_000_000_000
            ))

            var pollFd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let pollResult = poll(&pollFd, 1, min(remainingMs, 100)) // 100ms max per poll to update progress

            guard pollResult > 0 else {
                if pollResult == 0 && remainingMs <= 1 { break } // Timed out
                continue
            }

            fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let received = withUnsafeMutablePointer(to: &fromAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    recvfrom(fd, &buf, buf.count, 0, sockaddrPtr, &fromLen)
                }
            }
            guard received > 0 else { continue }

            let recvTime = ContinuousClock.now

            // Parse: skip IP header if present
            let data = Array(buf[0..<received])
            var offset = 0
            if data.count >= 20 && (data[0] >> 4) == 4 {
                offset = Int(data[0] & 0x0F) * 4
            }

            guard data.count > offset + 7 else { continue }
            let icmpType = data[offset]
            // Type 0 = Echo Reply
            guard icmpType == 0 else { continue }

            // Extract identifier and sequence
            let respIdent = UInt16(data[offset + 4]) << 8 | UInt16(data[offset + 5])
            let respSeq = UInt16(data[offset + 6]) << 8 | UInt16(data[offset + 7])

            // Match our identifier
            guard respIdent == ident else { continue }

            // Match pending probe
            guard let probe = pending.removeValue(forKey: respSeq) else { continue }

            let elapsed = recvTime - probe.sendTime
            let rtt = Double(elapsed.components.seconds) * 1000.0
                + Double(elapsed.components.attoseconds) / 1e15

            await accumulator.updateLatency(ip: probe.ip, latency: rtt)
            enriched += 1

            let progress = 0.5 + 0.5 * Double(enriched) / Double(max(ipsNeedingLatency.count, 1))
            await onProgress(progress)
        }

        logger.info("ICMP ping sweep complete: \(enriched)/\(ipsNeedingLatency.count) devices enriched")
        await onProgress(1.0)
    }

    // MARK: - Packet Building

    /// Build an ICMP echo request packet (type 8, code 0).
    private static func buildEchoRequest(identifier: UInt16, sequence: UInt16, payloadSize: Int = 16) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: 8 + payloadSize)

        // Type 8 (Echo Request), Code 0
        packet[0] = 8
        packet[1] = 0

        // Identifier
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xFF)

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
