import Foundation

/// Global connection budget that caps the number of concurrent NWConnections
/// across all services to prevent kernel socket exhaustion, reduce CPU heat,
/// and avoid GCD thread pool starvation.
///
/// Services must call `acquire()` before creating an NWConnection and
/// `release()` when the connection is cancelled or completes.
actor ConnectionBudget {
    static let shared = ConnectionBudget(limit: 30)

    private let limit: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
    }

    /// Wait until a connection slot is available, then claim it.
    func acquire() async {
        if active < limit {
            active += 1
            return
        }
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
        active += 1
    }

    /// Release a connection slot, waking the next waiter if any.
    func release() {
        active = max(active - 1, 0)
        if !waiters.isEmpty, active < limit {
            let next = waiters.removeFirst()
            next.resume()
        }
    }

    /// Current number of active connections (for diagnostics).
    var activeCount: Int { active }
}
