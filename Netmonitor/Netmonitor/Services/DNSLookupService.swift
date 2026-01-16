import Foundation
import dnssd

@MainActor
@Observable
final class DNSLookupService {
    private(set) var lastResult: DNSQueryResult?
    private(set) var isLoading: Bool = false
    private(set) var lastError: String?
    
    func lookup(
        domain: String,
        recordType: DNSRecordType = .a,
        server: String? = nil
    ) async -> DNSQueryResult? {
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        let start = Date()
        
        do {
            let records = try await performLookup(domain: domain, type: recordType)
            let queryTime = Date().timeIntervalSince(start) * 1000
            
            let result = DNSQueryResult(
                domain: domain,
                server: server ?? "System DNS",
                queryType: recordType,
                records: records,
                queryTime: queryTime
            )
            
            lastResult = result
            return result
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }
    
    private func performLookup(domain: String, type: DNSRecordType) async throws -> [DNSRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            
            var result: UnsafeMutablePointer<addrinfo>?
            let status = getaddrinfo(domain, nil, &hints, &result)
            
            guard status == 0, let addrInfo = result else {
                continuation.resume(throwing: DNSError.lookupFailed)
                return
            }
            
            defer { freeaddrinfo(result) }
            
            var records: [DNSRecord] = []
            var current: UnsafeMutablePointer<addrinfo>? = addrInfo
            
            while let info = current {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                
                let sockaddr = info.pointee.ai_addr
                let socklen = info.pointee.ai_addrlen
                
                getnameinfo(sockaddr, socklen, &hostname, socklen_t(hostname.count),
                           nil, 0, NI_NUMERICHOST)
                
                let address = String(cString: hostname)
                let recordType: DNSRecordType = info.pointee.ai_family == AF_INET6 ? .aaaa : .a
                
                if (type == .a && recordType == .a) || (type == .aaaa && recordType == .aaaa) || type == .a {
                    let record = DNSRecord(
                        name: domain,
                        type: recordType,
                        value: address,
                        ttl: 300
                    )
                    records.append(record)
                }
                
                current = info.pointee.ai_next
            }
            
            continuation.resume(returning: records)
        }
    }
}

enum DNSError: LocalizedError {
    case lookupFailed
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .lookupFailed: "DNS lookup failed"
        case .timeout: "DNS query timed out"
        }
    }
}
