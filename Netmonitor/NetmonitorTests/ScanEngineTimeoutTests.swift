import Testing
import Foundation
@testable import Netmonitor
import NetworkScanKit

// MARK: - Thread-safe tracker for phase execution

private actor PhaseTracker {
    private var _phases: Set<String> = []

    func mark(_ id: String) {
        _phases.insert(id)
    }

    func didRun(_ id: String) -> Bool {
        _phases.contains(id)
    }
}

// MARK: - Mock Phases for Timeout Testing

/// A phase that completes immediately, recording that it ran.
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

/// A phase that hangs until cancelled (simulates a stuck NWConnection).
private struct HangingPhase: ScanPhase {
    let id: String
    let displayName: String
    let weight: Double

    init(id: String = "hanging", displayName: String = "Hanging", weight: Double = 1.0) {
        self.id = id
        self.displayName = displayName
        self.weight = weight
    }

    func execute(
        context: ScanContext,
        accumulator: ScanAccumulator,
        onProgress: @Sendable (Double) async -> Void
    ) async {
        // Simulate a stuck phase — sleep for a very long time, respecting cancellation
        try? await Task.sleep(for: .seconds(600))
    }
}

// MARK: - ScanEngine Timeout Tests

@Suite("ScanEngine Per-Phase Timeout Tests")
struct ScanEngineTimeoutTests {

    private func makeContext() -> ScanContext {
        ScanContext(hosts: [], subnetFilter: { _ in true }, localIP: nil)
    }

    @Test("Normal phases complete without being cut off by timeout")
    func normalPhasesComplete() async {
        let engine = ScanEngine()
        let context = makeContext()
        let tracker = PhaseTracker()

        let pipeline = ScanPipeline(steps: [
            ScanPipeline.Step(phases: [
                InstantPhase(id: "p1", displayName: "Phase 1", tracker: tracker),
            ], concurrent: false),
            ScanPipeline.Step(phases: [
                InstantPhase(id: "p2", displayName: "Phase 2", tracker: tracker),
            ], concurrent: false),
        ])

        _ = await engine.scan(pipeline: pipeline, context: context) { _, _ in }

        #expect(await tracker.didRun("p1"))
        #expect(await tracker.didRun("p2"))
    }

    @Test("Hanging phase gets cancelled by timeout and pipeline continues")
    func hangingPhaseCancelledByTimeout() async {
        let engine = ScanEngine()
        let context = makeContext()
        let tracker = PhaseTracker()

        // Pipeline: hanging phase (will timeout) -> instant phase (should still run)
        let pipeline = ScanPipeline(steps: [
            ScanPipeline.Step(phases: [
                HangingPhase(id: "stuck", displayName: "Stuck Phase"),
            ], concurrent: false),
            ScanPipeline.Step(phases: [
                InstantPhase(id: "after", displayName: "After Hang", tracker: tracker),
            ], concurrent: false),
        ])

        // The phaseTimeout is 30s in ScanEngine. We expect the hanging phase to be
        // cancelled after 30s and then the pipeline continues to the next step.
        // This test validates the timeout mechanism works — it will take ~30s to run.
        let start = ContinuousClock.now
        _ = await engine.scan(pipeline: pipeline, context: context) { _, _ in }
        let elapsed = ContinuousClock.now - start

        // The hanging phase should have been cut off around the 30s mark
        #expect(elapsed < .seconds(35))
        #expect(elapsed >= .seconds(28))

        // The phase after the hanging one must have run
        #expect(await tracker.didRun("after"))
    }
}
