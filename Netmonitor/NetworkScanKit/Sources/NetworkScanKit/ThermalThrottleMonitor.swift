import Foundation

/// Monitors device thermal state and provides concurrency multipliers
/// to reduce network activity when the device is overheating.
///
/// Thermal state mapping:
/// - `.nominal` / `.fair` → 1.0× (full concurrency)
/// - `.serious` → 0.5× (half concurrency)
/// - `.critical` → 0.25× (quarter concurrency)
public final class ThermalThrottleMonitor: @unchecked Sendable {
    public static let shared = ThermalThrottleMonitor()

    private let lock = NSLock()
    private var _multiplier: Double
    private var observer: (any NSObjectProtocol)?

    private init() {
        _multiplier = Self.mapState(ProcessInfo.processInfo.thermalState)
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            let newState = ProcessInfo.processInfo.thermalState
            self.lock.withLock { self._multiplier = Self.mapState(newState) }
        }
    }

    /// Current thermal multiplier (1.0 = full, 0.5 = half, 0.25 = quarter).
    public var multiplier: Double {
        lock.withLock { _multiplier }
    }

    /// Compute an effective concurrency limit from a base value, reduced by thermal state.
    /// Always returns at least 1.
    public func effectiveLimit(from baseLimit: Int) -> Int {
        max(1, Int(Double(baseLimit) * multiplier))
    }

    private static func mapState(_ state: ProcessInfo.ThermalState) -> Double {
        switch state {
        case .nominal, .fair: return 1.0
        case .serious: return 0.5
        case .critical: return 0.25
        @unknown default: return 1.0
        }
    }
}
