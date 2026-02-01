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

    private let bonjourService = BonjourDiscoveryService()
    private var discoveryTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var groupedServices: [String: [BonjourService]] {
        Dictionary(grouping: services, by: { $0.serviceCategory })
    }

    var sortedCategories: [String] {
        groupedServices.keys.sorted()
    }

    // MARK: - Actions

    func startDiscovery() {
        stopDiscovery()
        isDiscovering = true
        hasDiscoveredOnce = true
        errorMessage = nil
        services = []

        discoveryTask = Task {
            let stream = bonjourService.discoveryStream()

            for await service in stream {
                services.append(service)
            }

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
