import Foundation

/// ViewModel for the Ping tool view
@MainActor
@Observable
final class PingToolViewModel {
    // MARK: - Input Properties

    var host: String = ""
    var pingCount: Int = 4

    // MARK: - State Properties

    var isRunning: Bool = false
    var results: [PingResult] = []
    var statistics: PingStatistics?
    var errorMessage: String?

    // MARK: - Configuration

    let availablePingCounts = [4, 10, 20, 50, 100]

    // MARK: - Dependencies

    private let pingService = PingService()
    private var pingTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var canStartPing: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty && !isRunning
    }

    // MARK: - Actions

    func startPing() {
        guard canStartPing else { return }

        clearResults()
        isRunning = true

        pingTask = Task {
            let stream = await pingService.ping(
                host: host.trimmingCharacters(in: .whitespaces),
                count: pingCount
            )

            for await result in stream {
                results.append(result)
            }

            // Calculate statistics after completion
            statistics = await pingService.calculateStatistics(results, requestedCount: pingCount)
            isRunning = false
        }
    }

    func stopPing() {
        pingTask?.cancel()
        pingTask = nil
        Task {
            await pingService.stop()
        }
        isRunning = false
    }

    func clearResults() {
        results.removeAll()
        statistics = nil
        errorMessage = nil
    }
}
