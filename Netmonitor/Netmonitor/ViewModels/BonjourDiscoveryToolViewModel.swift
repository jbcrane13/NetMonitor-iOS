import Foundation

/// ViewModel for the Bonjour Discovery tool view
@MainActor
@Observable
final class BonjourDiscoveryToolViewModel {
    // MARK: - State Properties

    var isDiscovering: Bool = false
    var hasDiscoveredOnce: Bool = false
    var services: [BonjourService] = []
    var errorMessage: String?

    // MARK: - Dependencies

    private let bonjourService: any BonjourDiscoveryServiceProtocol
    private var discoveryTask: Task<Void, Never>?

    /// Monotonic counter so a finishing old stream doesn't clobber
    /// state that belongs to a newer discovery run.
    private var runID: UInt64 = 0

    init(bonjourService: any BonjourDiscoveryServiceProtocol = BonjourDiscoveryService()) {
        self.bonjourService = bonjourService
    }

    // MARK: - Computed Properties

    var groupedServices: [String: [BonjourService]] {
        Dictionary(grouping: services, by: { $0.serviceCategory })
    }

    var sortedCategories: [String] {
        groupedServices.keys.sorted()
    }

    // MARK: - Actions

    func startDiscovery() {
        // Cancel the previous task (if any) without going through stopDiscovery,
        // because stopDiscovery resets isDiscovering and we're about to set it true.
        discoveryTask?.cancel()
        discoveryTask = nil

        runID &+= 1
        let currentRun = runID

        isDiscovering = true
        hasDiscoveredOnce = true
        errorMessage = nil
        services = []

        discoveryTask = Task {
            let stream = bonjourService.discoveryStream(serviceType: nil)

            for await service in stream {
                guard !Task.isCancelled, currentRun == runID else { break }
                services.append(service)
            }

            // Only update state if this is still the active run.
            // Prevents a stale task from resetting isDiscovering after
            // a new discovery was already started.
            guard currentRun == runID else { return }
            isDiscovering = false
        }
    }

    func stopDiscovery() {
        discoveryTask?.cancel()
        discoveryTask = nil
        bonjourService.stopDiscovery()
        isDiscovering = false
    }

    func clearResults() {
        services.removeAll()
        errorMessage = nil
    }
}
