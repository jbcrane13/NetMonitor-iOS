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
        // Use getaddrinfo for A and AAAA records
        if type == .a || type == .aaaa {
            return try await performAddressLookup(domain: domain, type: type)
        }

        // Use DNSServiceQueryRecord for other record types
        return try await performDNSServiceLookup(domain: domain, type: type)
    }

    private func performAddressLookup(domain: String, type: DNSRecordType) async throws -> [DNSRecord] {
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

                if (type == .a && recordType == .a) || (type == .aaaa && recordType == .aaaa) {
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

    private func performDNSServiceLookup(domain: String, type: DNSRecordType) async throws -> [DNSRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            var serviceRef: DNSServiceRef?
            var records: [DNSRecord] = []
            var resumed = false

            let rrtype = dnsRecordTypeToConstant(type)

            let callback: DNSServiceQueryRecordReply = { _, flags, _, errorCode, _, rrtype, _, rdlen, rdata, ttl, context in
                guard errorCode == kDNSServiceErr_NoError else { return }
                guard let context = context else { return }

                let contextPtr = context.assumingMemoryBound(to: QueryContext.self)
                let queryContext = contextPtr.pointee

                guard !queryContext.resumed else { return }

                if let record = DNSLookupService.parseRecord(
                    domain: queryContext.domain,
                    type: queryContext.recordType,
                    rdata: rdata,
                    rdlen: rdlen,
                    ttl: ttl
                ) {
                    queryContext.records.append(record)
                }

                // If MoreComing flag is not set, we're done
                if (flags & kDNSServiceFlagsMoreComing) == 0 {
                    queryContext.resumed = true
                    queryContext.continuation.resume(returning: queryContext.records)
                }
            }

            var context = QueryContext(
                domain: domain,
                recordType: type,
                records: [],
                continuation: continuation,
                resumed: false
            )

            withUnsafeMutablePointer(to: &context) { contextPtr in
                let error = DNSServiceQueryRecord(
                    &serviceRef,
                    0, // flags
                    0, // interfaceIndex (0 = all interfaces)
                    domain,
                    UInt16(rrtype),
                    UInt16(kDNSServiceClass_IN),
                    callback,
                    contextPtr
                )

                guard error == kDNSServiceErr_NoError, let service = serviceRef else {
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: DNSError.lookupFailed)
                    }
                    return
                }

                // Schedule on run loop
                let socket = DNSServiceRefSockFD(service)
                let source = DispatchSource.makeReadSource(fileDescriptor: socket)

                source.setEventHandler {
                    DNSServiceProcessResult(service)
                }

                source.setCancelHandler {
                    DNSServiceRefDeallocate(service)
                }

                source.resume()

                // Set timeout
                DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
                    source.cancel()
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: DNSError.timeout)
                    }
                }
            }
        }
    }

    private func dnsRecordTypeToConstant(_ type: DNSRecordType) -> Int32 {
        switch type {
        case .a: return Int32(kDNSServiceType_A)
        case .aaaa: return Int32(kDNSServiceType_AAAA)
        case .mx: return 15 // kDNSServiceType_MX
        case .txt: return 16 // kDNSServiceType_TXT
        case .cname: return 5 // kDNSServiceType_CNAME
        case .ns: return 2 // kDNSServiceType_NS
        case .soa: return 6 // kDNSServiceType_SOA
        case .ptr: return 12 // kDNSServiceType_PTR
        }
    }

    private static func parseRecord(
        domain: String,
        type: DNSRecordType,
        rdata: UnsafeRawPointer?,
        rdlen: UInt16,
        ttl: UInt32
    ) -> DNSRecord? {
        guard let rdata = rdata, rdlen > 0 else { return nil }

        let data = Data(bytes: rdata, count: Int(rdlen))

        switch type {
        case .mx:
            return parseMXRecord(domain: domain, data: data, ttl: ttl)
        case .txt:
            return parseTXTRecord(domain: domain, data: data, ttl: ttl)
        case .cname, .ns, .ptr:
            return parseDomainNameRecord(domain: domain, type: type, data: data, ttl: ttl)
        case .soa:
            return parseSOARecord(domain: domain, data: data, ttl: ttl)
        default:
            return nil
        }
    }

    private static func parseMXRecord(domain: String, data: Data, ttl: UInt32) -> DNSRecord? {
        guard data.count >= 2 else { return nil }

        let priority = data.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        let nameData = data.dropFirst(2)

        guard let mailServer = parseDNSName(from: nameData) else { return nil }

        return DNSRecord(
            name: domain,
            type: .mx,
            value: mailServer,
            ttl: Int(ttl),
            priority: Int(priority)
        )
    }

    private static func parseTXTRecord(domain: String, data: Data, ttl: UInt32) -> DNSRecord? {
        var offset = 0
        var strings: [String] = []

        while offset < data.count {
            let length = Int(data[offset])
            offset += 1

            guard offset + length <= data.count else { break }

            let stringData = data[offset..<offset + length]
            if let string = String(data: stringData, encoding: .utf8) {
                strings.append(string)
            }
            offset += length
        }

        return DNSRecord(
            name: domain,
            type: .txt,
            value: strings.joined(separator: "\n"),
            ttl: Int(ttl)
        )
    }

    private static func parseDomainNameRecord(domain: String, type: DNSRecordType, data: Data, ttl: UInt32) -> DNSRecord? {
        guard let name = parseDNSName(from: data) else { return nil }

        return DNSRecord(
            name: domain,
            type: type,
            value: name,
            ttl: Int(ttl)
        )
    }

    private static func parseSOARecord(domain: String, data: Data, ttl: UInt32) -> DNSRecord? {
        var offset = 0

        // Parse mname (primary name server)
        guard let mname = parseDNSName(from: data[offset...], offset: &offset) else { return nil }

        // Parse rname (responsible authority's mailbox)
        guard let rname = parseDNSName(from: data[offset...], offset: &offset) else { return nil }

        // Parse 5 UInt32 values: serial, refresh, retry, expire, minimum
        guard offset + 20 <= data.count else { return nil }

        let values = data[offset..<offset + 20].withUnsafeBytes { ptr in
            (0..<5).map { i in
                ptr.load(fromByteOffset: i * 4, as: UInt32.self).bigEndian
            }
        }

        let soaValue = """
        \(mname) \(rname) (
          Serial: \(values[0])
          Refresh: \(values[1])
          Retry: \(values[2])
          Expire: \(values[3])
          Minimum: \(values[4])
        )
        """

        return DNSRecord(
            name: domain,
            type: .soa,
            value: soaValue,
            ttl: Int(ttl)
        )
    }

    private static func parseDNSName(from data: Data, offset: inout Int) -> String? {
        var labels: [String] = []
        var currentOffset = offset

        while currentOffset < data.count {
            let length = Int(data[currentOffset])
            currentOffset += 1

            if length == 0 {
                offset = currentOffset
                return labels.joined(separator: ".")
            }

            guard currentOffset + length <= data.count else { return nil }

            let labelData = data[currentOffset..<currentOffset + length]
            guard let label = String(data: labelData, encoding: .utf8) else { return nil }

            labels.append(label)
            currentOffset += length
        }

        return nil
    }

    private static func parseDNSName(from data: Data) -> String? {
        var offset = 0
        return parseDNSName(from: data, offset: &offset)
    }
}

private class QueryContext {
    let domain: String
    let recordType: DNSRecordType
    var records: [DNSRecord]
    let continuation: CheckedContinuation<[DNSRecord], Error>
    var resumed: Bool

    init(
        domain: String,
        recordType: DNSRecordType,
        records: [DNSRecord],
        continuation: CheckedContinuation<[DNSRecord], Error>,
        resumed: Bool
    ) {
        self.domain = domain
        self.recordType = recordType
        self.records = records
        self.continuation = continuation
        self.resumed = resumed
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
