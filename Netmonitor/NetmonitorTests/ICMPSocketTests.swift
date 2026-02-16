import Testing
@testable import Netmonitor

@Suite("ICMPSocket Tests")
struct ICMPSocketTests {

    // MARK: - Checksum Tests

    @Test("Checksum of all zeros produces 0xFFFF")
    func checksumAllZeros() {
        let data: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0xFFFF)
    }

    @Test("Checksum of 0xFFFF words produces 0x0000")
    func checksumAllOnes() {
        let data: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0x0000)
    }

    @Test("Checksum handles odd-length data")
    func checksumOddLength() {
        // 3 bytes: [0x01, 0x02, 0x03]
        // Sum: 0x0102 + 0x0300 = 0x0402
        // Complement: ~0x0402 = 0xFBFD
        let data: [UInt8] = [0x01, 0x02, 0x03]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0xFBFD)
    }

    @Test("Checksum is self-verifying (recompute over packet with checksum yields 0)")
    func checksumSelfVerifying() {
        // Build a packet, compute checksum, insert it, then verify
        var packet: [UInt8] = [8, 0, 0, 0, 0, 1, 0, 1] // Echo request, id=1, seq=1
        let checksum = ICMPSocket.icmpChecksum(packet)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)

        // Recomputing over the complete packet (with checksum) should yield 0
        let verify = ICMPSocket.icmpChecksum(packet)
        #expect(verify == 0)
    }

    @Test("Checksum matches known ICMP echo request vector")
    func checksumKnownVector() {
        // ICMP Echo Request: type=8, code=0, checksum=0, id=0x1234, seq=0x0001
        // Payload: 8 bytes of 0x00
        var packet: [UInt8] = [
            8, 0, 0, 0,        // type, code, checksum placeholder
            0x12, 0x34,         // identifier
            0x00, 0x01,         // sequence
            0, 0, 0, 0, 0, 0, 0, 0  // payload
        ]

        let checksum = ICMPSocket.icmpChecksum(packet)

        // Insert checksum and verify it produces 0 on re-check
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)
        #expect(ICMPSocket.icmpChecksum(packet) == 0)
    }

    @Test("Checksum handles carry folding correctly")
    func checksumCarryFolding() {
        // Two words that produce a carry when summed
        // 0xFFFE + 0x0003 = 0x10001 → fold → 0x0002 → complement → 0xFFFD
        let data: [UInt8] = [0xFF, 0xFE, 0x00, 0x03]
        let result = ICMPSocket.icmpChecksum(data)
        #expect(result == 0xFFFD)
    }

    // MARK: - Packet Construction Tests

    @Test("buildEchoRequest produces correct header structure")
    func buildEchoRequestHeader() {
        let packet = ICMPSocket.buildEchoRequest(sequence: 42, payloadSize: 0, identifier: 0xABCD)

        #expect(packet.count == 8) // Header only, no payload

        // Type: Echo Request (8)
        #expect(packet[0] == 8)
        // Code: 0
        #expect(packet[1] == 0)
        // Identifier: 0xABCD (big-endian)
        #expect(packet[4] == 0xAB)
        #expect(packet[5] == 0xCD)
        // Sequence: 42 (big-endian)
        #expect(packet[6] == 0x00)
        #expect(packet[7] == 42)
    }

    @Test("buildEchoRequest includes payload pattern")
    func buildEchoRequestPayload() {
        let payloadSize = 16
        let packet = ICMPSocket.buildEchoRequest(sequence: 1, payloadSize: payloadSize)

        #expect(packet.count == 8 + payloadSize)

        // Verify payload pattern (repeating 0..255)
        for i in 0..<payloadSize {
            #expect(packet[8 + i] == UInt8(i & 0xFF))
        }
    }

    @Test("buildEchoRequest has valid checksum")
    func buildEchoRequestChecksum() {
        let packet = ICMPSocket.buildEchoRequest(sequence: 1, payloadSize: 56)

        // Verifying checksum: recomputing over the entire packet should yield 0
        let verify = ICMPSocket.icmpChecksum(packet)
        #expect(verify == 0)
    }

    @Test("buildEchoRequest standard 64-byte ping packet")
    func buildStandardPingPacket() {
        // Standard ping: 8 byte header + 56 byte payload = 64 bytes
        let packet = ICMPSocket.buildEchoRequest(sequence: 1, payloadSize: 56)
        #expect(packet.count == 64)
        #expect(ICMPSocket.icmpChecksum(packet) == 0) // Valid checksum
    }

    // MARK: - Response Parsing Tests

    @Test("parseResponse handles echo reply correctly")
    func parseEchoReply() {
        // Simulate an ICMP Echo Reply: type=0, code=0, checksum, id, seq=5
        let buffer: [UInt8] = [
            0, 0,               // type=0 (echo reply), code=0
            0x00, 0x00,         // checksum (don't care for parsing)
            0x00, 0x01,         // identifier
            0x00, 0x05,         // sequence=5
        ]

        let response = ICMPSocket.parseResponse(
            buffer: buffer,
            sourceIP: "8.8.8.8",
            rtt: 15.5
        )

        if case .echoReply(let seq) = response.kind {
            #expect(seq == 5)
        } else {
            Issue.record("Expected echoReply, got \(response.kind)")
        }
        #expect(response.sourceIP == "8.8.8.8")
        #expect(response.rtt == 15.5)
    }

    @Test("parseResponse handles time exceeded correctly")
    func parseTimeExceeded() {
        // ICMP Time Exceeded message structure:
        // [0-7]   Time Exceeded ICMP header: type=11, code=0, checksum, unused
        // [8-27]  Original IP header (20 bytes)
        // [28-35] First 8 bytes of original ICMP: type=8, code=0, checksum, id, seq=3
        var buffer = [UInt8](repeating: 0, count: 36)
        buffer[0] = 11  // type = Time Exceeded
        buffer[1] = 0   // code = TTL exceeded in transit

        // Original IP header at offset 8 (20 bytes of placeholder)
        // Original ICMP at offset 28
        buffer[28] = 8   // original type = Echo Request
        buffer[29] = 0   // original code
        // original checksum at 30-31 (don't care)
        // original identifier at 32-33 (don't care for SOCK_DGRAM)
        buffer[34] = 0x00 // original sequence high byte
        buffer[35] = 0x03 // original sequence low byte = 3

        let response = ICMPSocket.parseResponse(
            buffer: buffer,
            sourceIP: "10.0.0.1",
            rtt: 5.2
        )

        if case .timeExceeded(let routerIP, let origSeq) = response.kind {
            #expect(routerIP == "10.0.0.1")
            #expect(origSeq == 3)
        } else {
            Issue.record("Expected timeExceeded, got \(response.kind)")
        }
        #expect(response.rtt == 5.2)
    }

    @Test("parseResponse handles truncated time exceeded gracefully")
    func parseTimeExceededTruncated() {
        // Time exceeded with only 20 bytes (not enough for original ICMP)
        var buffer = [UInt8](repeating: 0, count: 20)
        buffer[0] = 11 // type = Time Exceeded

        let response = ICMPSocket.parseResponse(
            buffer: buffer,
            sourceIP: "10.0.0.1",
            rtt: 3.0
        )

        // Should still parse as time exceeded, but with sequence 0
        if case .timeExceeded(_, let origSeq) = response.kind {
            #expect(origSeq == 0)
        } else {
            Issue.record("Expected timeExceeded, got \(response.kind)")
        }
    }

    @Test("parseResponse handles unknown ICMP type as error")
    func parseUnknownType() {
        let buffer: [UInt8] = [
            3, 1,               // type=3 (Destination Unreachable), code=1 (Host Unreachable)
            0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
        ]

        let response = ICMPSocket.parseResponse(
            buffer: buffer,
            sourceIP: "192.168.1.1",
            rtt: 1.0
        )

        if case .error = response.kind {
            // Expected
        } else {
            Issue.record("Expected error for unknown ICMP type, got \(response.kind)")
        }
    }

    @Test("parseResponse handles too-short buffer as error")
    func parseTooShort() {
        let buffer: [UInt8] = [0, 0, 0] // Only 3 bytes, need at least 8

        let response = ICMPSocket.parseResponse(
            buffer: buffer,
            sourceIP: nil,
            rtt: 0
        )

        if case .error = response.kind {
            // Expected
        } else {
            Issue.record("Expected error for short buffer, got \(response.kind)")
        }
    }

    // MARK: - PingResult Model Tests

    @Test("PingResult method field defaults to TCP")
    func pingResultDefaultMethod() {
        let result = PingResult(
            sequence: 1,
            host: "test.com",
            ttl: 64,
            time: 10.0
        )
        #expect(result.method == .tcp)
    }

    @Test("PingResult method field can be set to ICMP")
    func pingResultICMPMethod() {
        let result = PingResult(
            sequence: 1,
            host: "test.com",
            ttl: 64,
            time: 10.0,
            method: .icmp
        )
        #expect(result.method == .icmp)
    }

    @Test("PingMethod raw values are correct")
    func pingMethodRawValues() {
        #expect(PingMethod.icmp.rawValue == "ICMP")
        #expect(PingMethod.tcp.rawValue == "TCP")
    }

    // MARK: - ICMPResponse Model Tests

    @Test("ICMPResponse echo reply carries correct data")
    func icmpResponseEchoReply() {
        let response = ICMPResponse(
            kind: .echoReply(sequence: 42),
            sourceIP: "1.2.3.4",
            rtt: 12.5
        )

        if case .echoReply(let seq) = response.kind {
            #expect(seq == 42)
        } else {
            Issue.record("Expected echoReply")
        }
        #expect(response.sourceIP == "1.2.3.4")
        #expect(response.rtt == 12.5)
    }

    @Test("ICMPResponse timeout has no source IP")
    func icmpResponseTimeout() {
        let response = ICMPResponse(
            kind: .timeout,
            sourceIP: nil,
            rtt: 2000.0
        )

        if case .timeout = response.kind {
            // Expected
        } else {
            Issue.record("Expected timeout")
        }
        #expect(response.sourceIP == nil)
    }
}
