import Testing
@testable import Netmonitor

@Suite("DNSLookupService Tests")
struct DNSLookupServiceTests {

    @Test("Service initializes with nil state")
    func initialState() async {
        let service = await DNSLookupService()
        let isLoading = await service.isLoading
        let lastResult = await service.lastResult
        let lastError = await service.lastError

        #expect(isLoading == false)
        #expect(lastResult == nil)
        #expect(lastError == nil)
    }

    @Test("A record lookup for known domain works", .disabled("Requires live network — integration test"))
    func lookupARecord() async {
        let service = await DNSLookupService()
        
        let result = await service.lookup(domain: "google.com", recordType: .a, server: nil)
        
        #expect(result != nil)
        if let result = result {
            #expect(result.domain == "google.com")
            #expect(result.queryType == .a)
            #expect(result.records.isEmpty == false)
            #expect(result.queryTime > 0)
            
            // Should have at least one A record
            let aRecords = result.records.filter { $0.type == .a }
            #expect(aRecords.isEmpty == false)
            
            // Verify IP address format (basic validation)
            if let firstRecord = aRecords.first {
                #expect(firstRecord.value.contains("."))
                #expect(firstRecord.ttl > 0)
            }
        }
        
        let finalIsLoading = await service.isLoading
        let finalError = await service.lastError
        #expect(finalIsLoading == false)
        #expect(finalError == nil)
    }

    @Test("AAAA record lookup for IPv6 works", .disabled("Requires live network — integration test"))
    func lookupAAAARecord() async {
        let service = await DNSLookupService()
        
        let result = await service.lookup(domain: "google.com", recordType: .aaaa, server: nil)
        
        #expect(result != nil)
        if let result = result {
            #expect(result.domain == "google.com")
            #expect(result.queryType == .aaaa)
            
            // Google should have IPv6 records
            let aaaaRecords = result.records.filter { $0.type == .aaaa }
            if !aaaaRecords.isEmpty {
                // If IPv6 records exist, verify format
                if let firstRecord = aaaaRecords.first {
                    #expect(firstRecord.value.contains(":"))
                    #expect(firstRecord.ttl > 0)
                }
            }
        }
    }

    @Test("MX record lookup works", .disabled("Requires live network — integration test"))
    func lookupMXRecord() async {
        let service = await DNSLookupService()
        
        let result = await service.lookup(domain: "google.com", recordType: .mx, server: nil)
        
        #expect(result != nil)
        if let result = result {
            #expect(result.domain == "google.com")
            #expect(result.queryType == .mx)
            
            // Google should have MX records
            let mxRecords = result.records.filter { $0.type == .mx }
            #expect(mxRecords.isEmpty == false)
            
            if let firstMX = mxRecords.first {
                #expect(firstMX.priority != nil)
                #expect(firstMX.priority! > 0)
                #expect(firstMX.value.isEmpty == false)
            }
        }
    }

    @Test("TXT record lookup works", .disabled("Requires live network — integration test"))
    func lookupTXTRecord() async {
        let service = await DNSLookupService()
        
        let result = await service.lookup(domain: "google.com", recordType: .txt, server: nil)
        
        #expect(result != nil)
        if let result = result {
            #expect(result.domain == "google.com")
            #expect(result.queryType == .txt)
            
            // Google should have TXT records (SPF, verification, etc.)
            let txtRecords = result.records.filter { $0.type == .txt }
            #expect(txtRecords.isEmpty == false)
            
            if let firstTXT = txtRecords.first {
                #expect(firstTXT.value.isEmpty == false)
            }
        }
    }

    @Test("NS record lookup works", .disabled("Requires live network — integration test"))
    func lookupNSRecord() async {
        let service = await DNSLookupService()
        
        let result = await service.lookup(domain: "google.com", recordType: .ns, server: nil)
        
        #expect(result != nil)
        if let result = result {
            #expect(result.domain == "google.com")
            #expect(result.queryType == .ns)
            
            // Should have name server records
            let nsRecords = result.records.filter { $0.type == .ns }
            #expect(nsRecords.isEmpty == false)
            
            if let firstNS = nsRecords.first {
                #expect(firstNS.value.contains("."))
            }
        }
    }

    @Test("CNAME record lookup works", .disabled("Requires live network — integration test"))
    func lookupCNAMERecord() async {
        let service = await DNSLookupService()
        
        // Use a subdomain that likely has CNAME
        let result = await service.lookup(domain: "www.github.com", recordType: .cname, server: nil)
        
        #expect(result != nil)
        if let result = result {
            #expect(result.domain == "www.github.com")
            #expect(result.queryType == .cname)
            
            // May or may not have CNAME records depending on DNS setup
            let cnameRecords = result.records.filter { $0.type == .cname }
            
            if !cnameRecords.isEmpty {
                if let firstCNAME = cnameRecords.first {
                    #expect(firstCNAME.value.contains("."))
                }
            }
        }
    }

    @Test("Lookup invalid domain handles gracefully", .disabled("Requires live network — integration test"))
    func lookupInvalidDomain() async {
        let service = await DNSLookupService()
        
        let result = await service.lookup(domain: "definitely-not-a-real-domain-12345.invalid", recordType: .a, server: nil)
        
        // Should either return nil or have an error
        #expect(result == nil)
        
        let finalError = await service.lastError
        #expect(finalError != nil)
    }

    @Test("Lookup empty domain handles gracefully", .disabled("Requires live network — integration test"))
    func lookupEmptyDomain() async {
        let service = await DNSLookupService()
        
        let result = await service.lookup(domain: "", recordType: .a, server: nil)
        
        #expect(result == nil)
        
        let finalError = await service.lastError
        #expect(finalError != nil)
    }

    @Test("Service tracks loading state correctly", .disabled("Requires live network — integration test"))
    func loadingStateTracking() async {
        let service = await DNSLookupService()

        // Test that the service properly tracks loading state
        // by doing multiple sequential lookups and checking state before/after
        let initialLoading = await service.isLoading
        #expect(initialLoading == false)

        // Perform a lookup
        let result1 = await service.lookup(domain: "google.com", recordType: .a, server: nil)

        // After completion, should not be loading
        let afterFirst = await service.isLoading
        #expect(afterFirst == false)
        #expect(result1 != nil)

        // Perform another lookup
        let result2 = await service.lookup(domain: "cloudflare.com", recordType: .a, server: nil)

        // After second completion, should not be loading
        let afterSecond = await service.isLoading
        #expect(afterSecond == false)
        #expect(result2 != nil)

        // Last result should be from the most recent lookup
        let lastResult = await service.lastResult
        #expect(lastResult?.domain == "cloudflare.com")
    }

    @Test("Multiple record types for same domain", .disabled("Requires live network — integration test"))
    func multipleRecordTypes() async {
        let service = await DNSLookupService()
        
        let domain = "cloudflare.com"
        let recordTypes: [DNSRecordType] = [.a, .aaaa, .mx, .txt, .ns]
        
        for recordType in recordTypes {
            let result = await service.lookup(domain: domain, recordType: recordType, server: nil)
            
            #expect(result != nil)
            if let result = result {
                #expect(result.domain == domain)
                #expect(result.queryType == recordType)
                #expect(result.queryTime > 0)
                
                let lastResult = await service.lastResult
                #expect(lastResult?.domain == domain)
                #expect(lastResult?.queryType == recordType)
            }
        }
    }

    @Test("DNS record model properties work correctly")
    func dnsRecordModel() async {
        let record = DNSRecord(
            name: "example.com",
            type: .a,
            value: "203.0.113.1",
            ttl: 3600,
            priority: nil
        )
        
        #expect(record.name == "example.com")
        #expect(record.type == .a)
        #expect(record.value == "203.0.113.1")
        #expect(record.ttl == 3600)
        #expect(record.priority == nil)
        
        // Test TTL text formatting
        #expect(record.ttlText == "1h")
        
        // Test with different TTL values
        let shortTtl = DNSRecord(name: "test.com", type: .a, value: "1.2.3.4", ttl: 30)
        #expect(shortTtl.ttlText == "30s")
        
        let dayTtl = DNSRecord(name: "test.com", type: .a, value: "1.2.3.4", ttl: 86400)
        #expect(dayTtl.ttlText == "1d")
        
        let minuteTtl = DNSRecord(name: "test.com", type: .a, value: "1.2.3.4", ttl: 300)
        #expect(minuteTtl.ttlText == "5m")
    }

    @Test("DNS query result model properties work correctly")
    func dnsQueryResultModel() async {
        let records = [
            DNSRecord(name: "example.com", type: .a, value: "93.184.216.34", ttl: 3600),
            DNSRecord(name: "example.com", type: .a, value: "93.184.216.35", ttl: 3600)
        ]
        
        let result = DNSQueryResult(
            domain: "example.com",
            server: "8.8.8.8",
            queryType: .a,
            records: records,
            queryTime: 15.5
        )
        
        #expect(result.domain == "example.com")
        #expect(result.server == "8.8.8.8")
        #expect(result.queryType == .a)
        #expect(result.records.count == 2)
        #expect(result.queryTime == 15.5)
        #expect(result.queryTimeText == "16 ms") // Rounded to nearest millisecond
    }

    @Test("DNS record type enum properties work correctly")
    func dnsRecordTypeEnum() async {
        #expect(DNSRecordType.a.displayName == "A")
        #expect(DNSRecordType.aaaa.displayName == "AAAA")
        #expect(DNSRecordType.mx.displayName == "MX")
        #expect(DNSRecordType.txt.displayName == "TXT")
        #expect(DNSRecordType.cname.displayName == "CNAME")
        #expect(DNSRecordType.ns.displayName == "NS")
        #expect(DNSRecordType.soa.displayName == "SOA")
        #expect(DNSRecordType.ptr.displayName == "PTR")
    }

    @Test("Concurrent DNS lookups work correctly", .disabled("Requires live network — integration test"))
    func concurrentLookups() async {
        let service = await DNSLookupService()
        
        // Test that service can handle multiple rapid lookups
        let domains = ["google.com", "cloudflare.com", "github.com"]
        
        await withTaskGroup(of: (String, DNSQueryResult?).self) { group in
            for domain in domains {
                group.addTask { @Sendable in
                    let result = await service.lookup(domain: domain, recordType: .a, server: nil)
                    return (domain, result)
                }
            }
            
            var results: [String: DNSQueryResult?] = [:]
            for await (domain, result) in group {
                results[domain] = result
            }
            
            #expect(results.count == domains.count)
            
            // At least some lookups should succeed
            let successfulLookups = results.values.compactMap { $0 }
            #expect(successfulLookups.count > 0)
        }
    }
}
