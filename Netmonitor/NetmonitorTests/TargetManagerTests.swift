import Testing
import Foundation
@testable import Netmonitor

// MARK: - TargetManager Tests

@Suite("TargetManager Tests")
@MainActor
struct TargetManagerTests {

    // Helper: create a fresh TargetManager for isolated testing
    // Since TargetManager.shared is a singleton backed by UserDefaults,
    // we reset state before each test via the public API.
    private func cleanManager() -> TargetManager {
        let mgr = TargetManager.shared
        // Clear all saved targets
        while !mgr.savedTargets.isEmpty {
            mgr.removeFromSaved(mgr.savedTargets[0])
        }
        mgr.clearSelection()
        return mgr
    }

    // MARK: - Initial / Clean State

    @Test("Clean state has no current target")
    func cleanStateNoTarget() {
        let mgr = cleanManager()
        #expect(mgr.currentTarget == nil)
    }

    @Test("Clean state has empty saved targets")
    func cleanStateEmptySaved() {
        let mgr = cleanManager()
        #expect(mgr.savedTargets.isEmpty)
    }

    // MARK: - setTarget

    @Test("setTarget sets currentTarget")
    func setTargetSetsCurrentTarget() {
        let mgr = cleanManager()
        mgr.setTarget("8.8.8.8")
        #expect(mgr.currentTarget == "8.8.8.8")
    }

    @Test("setTarget adds to saved targets")
    func setTargetAddsToSaved() {
        let mgr = cleanManager()
        mgr.setTarget("8.8.8.8")
        #expect(mgr.savedTargets.contains("8.8.8.8"))
    }

    @Test("setTarget trims whitespace")
    func setTargetTrimsWhitespace() {
        let mgr = cleanManager()
        mgr.setTarget("  8.8.8.8  ")
        #expect(mgr.currentTarget == "8.8.8.8")
        #expect(mgr.savedTargets.contains("8.8.8.8"))
    }

    @Test("setTarget ignores empty string")
    func setTargetIgnoresEmpty() {
        let mgr = cleanManager()
        mgr.setTarget("")
        #expect(mgr.currentTarget == nil)
        #expect(mgr.savedTargets.isEmpty)
    }

    @Test("setTarget ignores whitespace-only string")
    func setTargetIgnoresWhitespace() {
        let mgr = cleanManager()
        mgr.setTarget("   ")
        #expect(mgr.currentTarget == nil)
        #expect(mgr.savedTargets.isEmpty)
    }

    @Test("setTarget moves duplicate to front")
    func setTargetMovesDuplicateToFront() {
        let mgr = cleanManager()
        mgr.setTarget("1.1.1.1")
        mgr.setTarget("8.8.8.8")
        mgr.setTarget("1.1.1.1")

        #expect(mgr.savedTargets.count == 2)
        #expect(mgr.savedTargets[0] == "1.1.1.1")
        #expect(mgr.savedTargets[1] == "8.8.8.8")
    }

    // MARK: - addToSaved

    @Test("addToSaved adds without selecting")
    func addToSavedDoesNotSelect() {
        let mgr = cleanManager()
        mgr.addToSaved("8.8.8.8")
        #expect(mgr.currentTarget == nil)
        #expect(mgr.savedTargets.contains("8.8.8.8"))
    }

    @Test("addToSaved trims whitespace")
    func addToSavedTrimsWhitespace() {
        let mgr = cleanManager()
        mgr.addToSaved("  google.com  ")
        #expect(mgr.savedTargets.contains("google.com"))
    }

    @Test("addToSaved ignores empty string")
    func addToSavedIgnoresEmpty() {
        let mgr = cleanManager()
        mgr.addToSaved("")
        #expect(mgr.savedTargets.isEmpty)
    }

    @Test("addToSaved caps at 10 targets")
    func addToSavedCapsAt10() {
        let mgr = cleanManager()
        for i in 1...12 {
            mgr.addToSaved("host\(i).example.com")
        }
        #expect(mgr.savedTargets.count == 10)
        // Most recent should be first
        #expect(mgr.savedTargets[0] == "host12.example.com")
        // Oldest beyond cap should be gone
        #expect(!mgr.savedTargets.contains("host1.example.com"))
        #expect(!mgr.savedTargets.contains("host2.example.com"))
    }

    @Test("addToSaved deduplicates and moves to front")
    func addToSavedDeduplicates() {
        let mgr = cleanManager()
        mgr.addToSaved("a.com")
        mgr.addToSaved("b.com")
        mgr.addToSaved("a.com")
        #expect(mgr.savedTargets.count == 2)
        #expect(mgr.savedTargets[0] == "a.com")
    }

    // MARK: - removeFromSaved

    @Test("removeFromSaved removes target")
    func removeFromSavedRemoves() {
        let mgr = cleanManager()
        mgr.addToSaved("8.8.8.8")
        mgr.removeFromSaved("8.8.8.8")
        #expect(mgr.savedTargets.isEmpty)
    }

    @Test("removeFromSaved clears currentTarget if it matches")
    func removeFromSavedClearsCurrent() {
        let mgr = cleanManager()
        mgr.setTarget("8.8.8.8")
        #expect(mgr.currentTarget == "8.8.8.8")
        mgr.removeFromSaved("8.8.8.8")
        #expect(mgr.currentTarget == nil)
    }

    @Test("removeFromSaved does not clear currentTarget if different")
    func removeFromSavedKeepsCurrent() {
        let mgr = cleanManager()
        mgr.setTarget("8.8.8.8")
        mgr.addToSaved("1.1.1.1")
        mgr.removeFromSaved("1.1.1.1")
        #expect(mgr.currentTarget == "8.8.8.8")
    }

    @Test("removeFromSaved does nothing for unknown target")
    func removeFromSavedIgnoresUnknown() {
        let mgr = cleanManager()
        mgr.addToSaved("8.8.8.8")
        mgr.removeFromSaved("nonexistent")
        #expect(mgr.savedTargets.count == 1)
    }

    // MARK: - removeFromSaved(at:)

    @Test("removeFromSaved at offsets removes correct items")
    func removeFromSavedAtOffsets() {
        let mgr = cleanManager()
        mgr.addToSaved("a.com")
        mgr.addToSaved("b.com")
        mgr.addToSaved("c.com")
        // Order: c.com, b.com, a.com
        mgr.removeFromSaved(at: IndexSet(integer: 1)) // removes b.com
        #expect(mgr.savedTargets.count == 2)
        #expect(!mgr.savedTargets.contains("b.com"))
    }

    @Test("removeFromSaved at offsets clears currentTarget if removed")
    func removeFromSavedAtOffsetsClearsCurrent() {
        let mgr = cleanManager()
        mgr.setTarget("a.com")
        mgr.addToSaved("b.com")
        // Order: b.com, a.com — currentTarget is a.com
        mgr.removeFromSaved(at: IndexSet(integer: 1)) // removes a.com
        #expect(mgr.currentTarget == nil)
    }

    // MARK: - clearSelection

    @Test("clearSelection clears currentTarget but keeps saved")
    func clearSelectionKeepsSaved() {
        let mgr = cleanManager()
        mgr.setTarget("8.8.8.8")
        mgr.clearSelection()
        #expect(mgr.currentTarget == nil)
        #expect(mgr.savedTargets.contains("8.8.8.8"))
    }

    // MARK: - Persistence

    @Test("Saved targets persist across access")
    func savedTargetsPersist() {
        let mgr = cleanManager()
        mgr.addToSaved("persistent.example.com")
        // Access the same singleton again — saved targets should still be there
        let mgr2 = TargetManager.shared
        #expect(mgr2.savedTargets.contains("persistent.example.com"))
    }

    // MARK: - Multiple operations

    @Test("Full workflow: add, select, switch, remove, clear")
    func fullWorkflow() {
        let mgr = cleanManager()

        // Add several targets
        mgr.addToSaved("router.local")
        mgr.addToSaved("nas.local")
        mgr.setTarget("server.local")

        #expect(mgr.currentTarget == "server.local")
        #expect(mgr.savedTargets.count == 3)

        // Switch target
        mgr.setTarget("router.local")
        #expect(mgr.currentTarget == "router.local")
        #expect(mgr.savedTargets.count == 3)

        // Remove a non-current target
        mgr.removeFromSaved("nas.local")
        #expect(mgr.savedTargets.count == 2)
        #expect(mgr.currentTarget == "router.local")

        // Clear selection
        mgr.clearSelection()
        #expect(mgr.currentTarget == nil)
        #expect(mgr.savedTargets.count == 2)
    }
}

// MARK: - ViewModel Initial Host Tests

@Suite("ViewModel initialHost pre-fill Tests")
@MainActor
struct ViewModelInitialHostTests {

    @Test("PingToolViewModel accepts initialHost")
    func pingInitialHost() {
        let vm = PingToolViewModel(initialHost: "10.0.0.1")
        #expect(vm.host == "10.0.0.1")
    }

    @Test("PingToolViewModel defaults to empty when no initialHost")
    func pingNoInitialHost() {
        let vm = PingToolViewModel()
        #expect(vm.host == "")
    }

    @Test("TracerouteToolViewModel accepts initialHost")
    func tracerouteInitialHost() {
        let vm = TracerouteToolViewModel(initialHost: "8.8.8.8")
        #expect(vm.host == "8.8.8.8")
    }

    @Test("TracerouteToolViewModel defaults to empty when no initialHost")
    func tracerouteNoInitialHost() {
        let vm = TracerouteToolViewModel()
        #expect(vm.host == "")
    }

    @Test("DNSLookupToolViewModel accepts initialDomain")
    func dnsInitialDomain() {
        let vm = DNSLookupToolViewModel(initialDomain: "example.com")
        #expect(vm.domain == "example.com")
    }

    @Test("DNSLookupToolViewModel defaults to empty when no initialDomain")
    func dnsNoInitialDomain() {
        let vm = DNSLookupToolViewModel()
        #expect(vm.domain == "")
    }

    @Test("PortScannerToolViewModel accepts initialHost")
    func portScannerInitialHost() {
        let vm = PortScannerToolViewModel(initialHost: "192.168.1.1")
        #expect(vm.host == "192.168.1.1")
    }

    @Test("PortScannerToolViewModel defaults to empty when no initialHost")
    func portScannerNoInitialHost() {
        let vm = PortScannerToolViewModel()
        #expect(vm.host == "")
    }

    @Test("WHOISToolViewModel accepts initialDomain")
    func whoisInitialDomain() {
        let vm = WHOISToolViewModel(initialDomain: "google.com")
        #expect(vm.domain == "google.com")
    }

    @Test("WHOISToolViewModel defaults to empty when no initialDomain")
    func whoisNoInitialDomain() {
        let vm = WHOISToolViewModel()
        #expect(vm.domain == "")
    }
}
