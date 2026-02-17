import Testing
import Foundation
@testable import Netmonitor
import NetworkScanKit

// MARK: - Thread-safe flag for concurrency tests

private actor Flag {
    private var _value = false

    func set() { _value = true }
    var value: Bool { _value }
}

// MARK: - ConnectionBudget Tests

@Suite("ConnectionBudget Tests")
struct ConnectionBudgetTests {

    @Test("Basic acquire/release cycle")
    func acquireReleaseCycle() async {
        let budget = ConnectionBudget(limit: 5)
        await budget.acquire()
        let active = await budget.activeCount
        #expect(active == 1)

        await budget.release()
        let afterRelease = await budget.activeCount
        #expect(afterRelease == 0)
    }

    @Test("Acquire blocks at limit, resumes on release")
    func acquireBlocksAtLimit() async {
        let budget = ConnectionBudget(limit: 2)

        // Fill both slots
        await budget.acquire()
        await budget.acquire()
        let active = await budget.activeCount
        #expect(active == 2)

        // Third acquire should block — release from another task to unblock it
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // This will block until a slot opens
                await budget.acquire()
            }
            group.addTask {
                // Small delay then release to unblock the waiter
                try? await Task.sleep(for: .milliseconds(50))
                await budget.release()
            }
            await group.waitForAll()
        }

        // Should have 2 active: original 1 remaining + newly acquired
        let finalActive = await budget.activeCount
        #expect(finalActive == 2)

        // Clean up
        await budget.release()
        await budget.release()
    }

    @Test("release() always resumes waiter even at limit (thermal deadlock fix)")
    func releaseAlwaysResumesWaiter() async {
        let budget = ConnectionBudget(limit: 1)
        let waiterResumed = Flag()

        // Fill the single slot
        await budget.acquire()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // This will block — the budget is full
                await budget.acquire()
                await waiterResumed.set()
            }
            group.addTask {
                // Wait briefly, then release
                try? await Task.sleep(for: .milliseconds(50))
                await budget.release()
            }
            await group.waitForAll()
        }

        // The waiter MUST have been resumed — this is the deadlock fix.
        // Previously, release() checked `active < effectiveLimit` which could
        // deadlock when thermal throttling reduced effectiveLimit mid-scan.
        // Now it unconditionally resumes the next waiter.
        #expect(await waiterResumed.value)

        // Clean up
        await budget.release()
    }

    @Test("reset() drains all waiters and zeros active count")
    func resetDrainsWaiters() async {
        let budget = ConnectionBudget(limit: 1)
        let waiter1Resumed = Flag()
        let waiter2Resumed = Flag()

        // Fill the slot
        await budget.acquire()

        await withTaskGroup(of: Void.self) { group in
            // Two waiters that will block
            group.addTask {
                await budget.acquire()
                await waiter1Resumed.set()
            }
            group.addTask {
                await budget.acquire()
                await waiter2Resumed.set()
            }
            group.addTask {
                // Wait for waiters to enqueue, then reset
                try? await Task.sleep(for: .milliseconds(100))
                await budget.reset()
            }
            await group.waitForAll()
        }

        // Both waiters should have been drained/resumed by reset
        #expect(await waiter1Resumed.value)
        #expect(await waiter2Resumed.value)

        // Active count should reflect only the two post-reset acquires
        // (reset zeros active, then each resumed waiter does active += 1)
        let active = await budget.activeCount
        #expect(active == 2)

        // Clean up
        await budget.reset()
    }
}
