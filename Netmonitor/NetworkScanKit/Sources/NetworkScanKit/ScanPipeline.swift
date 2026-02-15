import Foundation

/// Defines the ordering and concurrency of scan phases.
public struct ScanPipeline: Sendable {

    /// A single step in the pipeline, containing one or more phases.
    public struct Step: Sendable {
        /// Phases to execute in this step.
        public let phases: [any ScanPhase]

        /// When `true`, phases in this step run concurrently.
        public let concurrent: Bool

        public init(phases: [any ScanPhase], concurrent: Bool) {
            self.phases = phases
            self.concurrent = concurrent
        }
    }

    /// Ordered steps to execute.
    public var steps: [Step]

    public init(steps: [Step]) {
        self.steps = steps
    }

    /// The default scan pipeline:
    /// 1. [ARP + Bonjour] concurrent
    /// 2. [TCP Probe]
    /// 3. [SSDP]
    /// 4. [Reverse DNS]
    public static func standard(
        bonjourServiceProvider: @escaping @Sendable () async -> [BonjourServiceInfo] = { [] },
        bonjourStopProvider: (@Sendable () async -> Void)? = nil
    ) -> ScanPipeline {
        ScanPipeline(steps: [
            Step(phases: [
                ARPScanPhase(),
                BonjourScanPhase(
                    serviceProvider: bonjourServiceProvider,
                    stopProvider: bonjourStopProvider
                ),
            ], concurrent: true),
            Step(phases: [TCPProbeScanPhase()], concurrent: false),
            Step(phases: [SSDPScanPhase()], concurrent: false),
            Step(phases: [ReverseDNSScanPhase()], concurrent: false),
        ])
    }
}
