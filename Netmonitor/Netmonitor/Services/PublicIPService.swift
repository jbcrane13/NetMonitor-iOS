import Foundation

@MainActor
@Observable
final class PublicIPService {
    private(set) var ispInfo: ISPInfo?
    private(set) var isLoading: Bool = false
    private(set) var lastError: String?
    
    private let session: URLSession
    private var lastFetch: Date?
    private let cacheDuration: TimeInterval = 300
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        self.session = URLSession(configuration: config)
    }
    
    func fetchPublicIP(forceRefresh: Bool = false) async {
        if !forceRefresh,
           let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheDuration,
           ispInfo != nil {
            return
        }
        
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        do {
            ispInfo = try await fetchFromIPAPI()
            lastFetch = Date()
        } catch {
            lastError = error.localizedDescription
        }
    }
    
    private func fetchFromIPAPI() async throws -> ISPInfo {
        let url = URL(string: "https://ipapi.co/json/")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PublicIPError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(IPAPIResponse.self, from: data)
        
        return ISPInfo(
            publicIP: result.ip,
            ispName: result.org,
            asn: result.asn,
            organization: result.org,
            city: result.city,
            region: result.region,
            country: result.country_name,
            countryCode: result.country_code,
            timezone: result.timezone
        )
    }
}

enum PublicIPError: LocalizedError {
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid response from server"
        case .decodingError: "Could not parse response"
        }
    }
}

private struct IPAPIResponse: Decodable {
    let ip: String
    let city: String?
    let region: String?
    let country_name: String?
    let country_code: String?
    let org: String?
    let asn: String?
    let timezone: String?
}
