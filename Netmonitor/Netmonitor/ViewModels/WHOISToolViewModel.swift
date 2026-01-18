import Foundation

/// ViewModel for the WHOIS tool view
@MainActor
@Observable
final class WHOISToolViewModel {
    // MARK: - Input Properties

    var domain: String = ""

    // MARK: - State Properties

    var isLoading: Bool = false
    var result: WHOISResult?
    var errorMessage: String?

    // MARK: - Dependencies

    private let whoisService = WHOISService()

    // MARK: - Computed Properties

    var canStartLookup: Bool {
        !domain.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    // MARK: - Actions

    func lookup() async {
        guard canStartLookup else { return }

        isLoading = true
        errorMessage = nil

        do {
            result = try await whoisService.lookup(query: domain.trimmingCharacters(in: .whitespaces))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func clearResults() {
        result = nil
        errorMessage = nil
    }
}
