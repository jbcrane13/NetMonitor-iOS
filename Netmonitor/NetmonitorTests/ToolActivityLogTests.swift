import Testing
import Foundation
@testable import Netmonitor

// MARK: - ToolActivityLog Tests

@Suite("ToolActivityLog Tests")
struct ToolActivityLogTests {

    @Test("add() inserts at index 0 (newest first)")
    @MainActor
    func addInsertsAtFront() {
        let log = ToolActivityLog.shared
        log.clear()

        log.add(tool: "Ping", target: "1.1.1.1", result: "OK", success: true)
        log.add(tool: "DNS", target: "example.com", result: "Resolved", success: true)

        #expect(log.entries.count == 2)
        #expect(log.entries[0].tool == "DNS")
        #expect(log.entries[1].tool == "Ping")

        log.clear()
    }

    @Test("Max 20 entries enforced — oldest dropped")
    @MainActor
    func maxTwentyEntries() {
        let log = ToolActivityLog.shared
        log.clear()

        for i in 0..<25 {
            log.add(tool: "Tool\(i)", target: "target", result: "result", success: true)
        }

        #expect(log.entries.count == 20)
        // Newest (Tool24) should be at index 0, oldest kept is Tool5
        #expect(log.entries[0].tool == "Tool24")
        #expect(log.entries[19].tool == "Tool5")

        log.clear()
    }

    @Test("clear() empties entries")
    @MainActor
    func clearEmptiesEntries() {
        let log = ToolActivityLog.shared
        log.clear()

        log.add(tool: "Ping", target: "8.8.8.8", result: "OK", success: true)
        log.add(tool: "DNS", target: "google.com", result: "OK", success: true)
        #expect(log.entries.count == 2)

        log.clear()
        #expect(log.entries.isEmpty)
    }

    @Test("Entries have correct ToolActivityItem fields")
    @MainActor
    func entryFieldsCorrect() {
        let log = ToolActivityLog.shared
        log.clear()

        log.add(tool: "WHOIS", target: "example.org", result: "Found", success: false)

        let item = log.entries[0]
        #expect(item.tool == "WHOIS")
        #expect(item.target == "example.org")
        #expect(item.result == "Found")
        #expect(item.success == false)
        // timestamp should be very recent (within 2 seconds)
        #expect(abs(item.timestamp.timeIntervalSinceNow) < 2)

        log.clear()
    }
}
