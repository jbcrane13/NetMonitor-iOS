import Foundation

/// ViewModel for the Traceroute tool view
@MainActor
@Observable
final class TracerouteToolViewModel {
    // MARK: - Input Properties

    var host: String = ""
    var maxHops: Int = 30

    // MARK: - State Properties

    var isRunning: Bool = false
    var hops: [TracerouteHop] = []
    var errorMessage: String?

    // MARK: - Configuration

    let availableMaxHops = [15, 30, 64]

    // MARK: - Dependencies

    private let tracerouteService = TracerouteService()
    private var traceTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var canStartTrace: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty && !isRunning
    }

    var completedHops: Int {
        hops.count
    }

    // MARK: - Actions

    func startTrace() {
        guard canStartTrace else { return }

        clearResults()
        isRunning = true

        traceTask = Task {
            let stream = await tracerouteService.trace(
                host: host.trimmingCharacters(in: .whitespaces),
                maxHops: maxHops
            )

            for await hop in stream {
                hops.append(hop)
            }

            isRunning = false
        }
    }

    func stopTrace() {
        traceTask?.cancel()
        traceTask = nil
        Task {
            await tracerouteService.stop()
        }
        isRunning = false
    }

    func clearResults() {
        hops.removeAll()
        errorMessage = nil
    }
}
