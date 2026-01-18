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

    // MARK: - Computed Properties

    var groupedServices: [String: [BonjourService]] {
        Dictionary(grouping: services, by: { $0.serviceCategory })
    }

    var sortedCategories: [String] {
        groupedServices.keys.sorted()
    }

    // MARK: - Actions

    func startDiscovery() {
        isDiscovering = true
        hasDiscoveredOnce = true
        errorMessage = nil
        bonjourService.startDiscovery()

        // Update services from the service
        Task {
            while isDiscovering {
                services = bonjourService.discoveredServices
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    func stopDiscovery() {
        bonjourService.stopDiscovery()
        isDiscovering = false
    }

    func clearResults() {
        services.removeAll()
        errorMessage = nil
    }
}
