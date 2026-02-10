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
        stopDiscovery()
        isDiscovering = true
        hasDiscoveredOnce = true
        errorMessage = nil
        services = []

        discoveryTask = Task {
            let stream = bonjourService.discoveryStream(serviceType: nil)

            for await service in stream {
                // Only append if not cancelled
                guard !Task.isCancelled else { break }
                services.append(service)
            }

            // Stream ended - discovery stopped
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
