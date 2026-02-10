import Foundation

@MainActor
@Observable
final class MACVendorLookupService {
    private(set) var isLoading: Bool = false
    private var vendorCache: [String: String] = [:]
    private var lastRequestTime: Date = .distantPast

    private struct MACLookupResponse: Codable {
        let success: Bool
        let found: Bool
        let company: String?
    }

    func lookup(macAddress: String) async -> String? {
        let normalizedPrefix = normalizeMACPrefix(macAddress)

        // Check cache first
        if let cachedVendor = vendorCache[normalizedPrefix] {
            return cachedVendor
        }

        // Rate limiting: 1 request per second
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        if timeSinceLastRequest < 1.0 {
            try? await Task.sleep(nanoseconds: UInt64((1.0 - timeSinceLastRequest) * 1_000_000_000))
        }

        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "https://api.maclookup.app/v2/macs/\(normalizedPrefix)") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            lastRequestTime = Date()

            let decoder = JSONDecoder()
            let response = try decoder.decode(MACLookupResponse.self, from: data)

            if response.success, response.found, let company = response.company {
                vendorCache[normalizedPrefix] = company
                return company
            }

            return nil
        } catch {
            return nil
        }
    }

    private func normalizeMACPrefix(_ macAddress: String) -> String {
        // Remove all separators (colons, hyphens, dots)
        let cleaned = macAddress.replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")
            .uppercased()

        // Take first 6 characters (MAC prefix)
        return String(cleaned.prefix(6))
    }
}
