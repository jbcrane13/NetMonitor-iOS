import Testing
import Foundation
@testable import NetworkScanKit

// MARK: - Test Infrastructure

private actor PhaseTracker {
    private var _phases: Set<String> = []
    func mark(_ id: String) { _phases.insert(id) }
    func didRun(_ id: String) -> Bool { _phases.contains(id) }
}

private actor ProgressCollector {
    private(set) var values: [Double] = []
    func record(_ value: Double) { values.append(value) }
}

/// Phase that completes instantly, recording that it ran via a shared tracker.
private struct InstantPhase: ScanPhase {
    let id: String
    let displayName: String
    let weight: Double
    let tracker: PhaseTracker

    init(id: String, displayName: String = "Instant", weight: Double = 1.0, tracker: PhaseTracker) {
        self.id = id
        self.displayName = displayName
        self.weight = weight
        self.tracker = tracker
    }

    func execute(
        context: ScanContext,
        accumulator: ScanAccumulator,
        onProgress: @Sendable (Double) async -> Void
    ) async {
        await onProgress(0.5)
        await tracker.mark(id)
        await onProgress(1.0)
    }
}

// MARK: - ScanEngine Concurrent Phase Tests

@Suite("ScanEngine Concurrent Phase Tests")
struct ScanEngineConcurrentTests {

    private func makeContext() -> ScanContext {
        ScanContext(hosts: [], subnetFilter: { _ in true }, localIP: nil)
    }

    @Test("Both phases in a concurrent step all execute")
    func concurrentPhasesAllExecute() async {
        let engine = ScanEngine()
        let context = makeContext()
        let tracker = PhaseTracker()

        let pipeline = ScanPipeline(steps: [
            ScanPipeline.Step(phases: [
                InstantPhase(id: "concurrent-a", displayName: "Phase A", tracker: tracker),
                InstantPhase(id: "concurrent-b", displayName: "Phase B", tracker: tracker),
            ], concurrent: true),
        ])

        _ = await engine.scan(pipeline: pipeline, context: context) { _, _ in }

        #expect(await tracker.didRun("concurrent-a"))
        #expect(await tracker.didRun("concurrent-b"))
    }

    @Test("Progress callback fires with non-decreasing values across sequential phases")
    func progressValuesAreNonDecreasing() async {
        let engine = ScanEngine()
        let context = makeContext()
        let tracker = PhaseTracker()
        let collector = ProgressCollector()

        let pipeline = ScanPipeline(steps: [
            ScanPipeline.Step(phases: [
                InstantPhase(id: "step1", displayName: "Step 1", weight: 1.0, tracker: tracker),
            ], concurrent: false),
            ScanPipeline.Step(phases: [
                InstantPhase(id: "step2", displayName: "Step 2", weight: 1.0, tracker: tracker),
            ], concurrent: false),
        ])

        _ = await engine.scan(pipeline: pipeline, context: context) { progress, _ in
            await collector.record(progress)
        }

        let values = await collector.values
        #expect(!values.isEmpty)

        for i in 1..<values.count {
            #expect(values[i] >= values[i - 1])
        }

        // Final overall progress should reach at least 0.9
        #expect((values.last ?? 0) > 0.9)
    }
}

// MARK: - DiscoveredDevice Model Tests

@Suite("DiscoveredDevice Model Tests")
struct DiscoveredDeviceModelTests {

    @Test("Full initializer stores all fields correctly")
    func fullInitializerStoresAllFields() {
        let now = Date()
        let device = DiscoveredDevice(
            ipAddress: "192.168.1.42",
            hostname: "my-mac.local",
            vendor: "Apple, Inc.",
            macAddress: "a4:c3:f0:12:34:56",
            latency: 3.5,
            discoveredAt: now,
            source: .bonjour
        )

        #expect(device.ipAddress == "192.168.1.42")
        #expect(device.hostname == "my-mac.local")
        #expect(device.vendor == "Apple, Inc.")
        #expect(device.macAddress == "a4:c3:f0:12:34:56")
        #expect(device.latency == 3.5)
        #expect(device.discoveredAt == now)
        #expect(device.source == .bonjour)
    }

    @Test("Full initializer with all nil optional fields works")
    func fullInitializerWithNilOptionals() {
        let now = Date()
        let device = DiscoveredDevice(
            ipAddress: "10.0.0.1",
            hostname: nil,
            vendor: nil,
            macAddress: nil,
            latency: nil,
            discoveredAt: now,
            source: .local
        )

        #expect(device.ipAddress == "10.0.0.1")
        #expect(device.hostname == nil)
        #expect(device.vendor == nil)
        #expect(device.macAddress == nil)
        #expect(device.latency == nil)
        #expect(device.source == .local)
    }

    @Test("displayName falls back to ipAddress when hostname is nil")
    func displayNameFallsBackToIPAddress() {
        let device = DiscoveredDevice(
            ipAddress: "192.168.1.1",
            hostname: nil,
            vendor: nil,
            macAddress: nil,
            latency: nil,
            discoveredAt: Date(),
            source: .local
        )
        #expect(device.displayName == "192.168.1.1")
    }

    @Test("displayName uses hostname when present")
    func displayNameUsesHostname() {
        let device = DiscoveredDevice(
            ipAddress: "192.168.1.2",
            hostname: "router.local",
            vendor: nil,
            macAddress: nil,
            latency: nil,
            discoveredAt: Date(),
            source: .local
        )
        #expect(device.displayName == "router.local")
    }
}
