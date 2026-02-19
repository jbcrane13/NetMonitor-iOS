import Testing
@testable import Netmonitor
import Foundation

// MARK: - Mock DNS Lookup Service

@MainActor
final class MockDNSLookupService: DNSLookupServiceProtocol {
    private(set) var isLoading: Bool = false
    private(set) var lastError: String? = nil
    private(set) var lastResult: DNSQueryResult? = nil

    var mockResult: DNSQueryResult? = nil
    var mockError: String? = nil

    func lookup(domain: String, recordType: DNSRecordType, server: String?) async -> DNSQueryResult? {
        guard !domain.trimmingCharacters(in: .whitespaces).isEmpty else {
            lastError = "Domain cannot be empty"
            return nil
        }

        isLoading = true
        lastError = nil

        defer { isLoading = false }

        if let error = mockError {
            lastError = error
            return nil
        }

        lastResult = mockResult
        return mockResult
    }

    func configureError(_ error: String) {
        mockError = error
        mockResult = nil
    }

    func reset() {
        isLoading = false
        lastError = nil
        lastResult = nil
        mockResult = nil
        mockError = nil
    }
}

// MARK: - Mock Traceroute Service

actor MockTracerouteService: TracerouteServiceProtocol {
    private(set) var running: Bool = false
    private var mockHopsStorage: [TracerouteHop] = []

    func setMockHops(_ hops: [TracerouteHop]) {
        mockHopsStorage = hops
    }

    func trace(host: String, maxHops: Int?, timeout: TimeInterval?) async -> AsyncStream<TracerouteHop> {
        running = true
        let hops: [TracerouteHop]
        if let max = maxHops {
            hops = Array(mockHopsStorage.prefix(max))
        } else {
            hops = mockHopsStorage
        }

        let (stream, continuation) = AsyncStream.makeStream(of: TracerouteHop.self)

        Task { [weak self] in
            guard let self else {
                continuation.finish()
                return
            }
            for hop in hops {
                guard await self.running else { break }
                continuation.yield(hop)
            }
            await self.finishTrace()
            continuation.finish()
        }

        return stream
    }

    func stop() async {
        running = false
    }

    private func finishTrace() {
        running = false
    }
}

// MARK: - Mock WHOIS Service

actor MockWHOISLookupService: WHOISServiceProtocol {
    var mockResult: WHOISResult? = nil
    var mockError: Error? = nil

    enum MockError: LocalizedError {
        case timeout
        case networkFailure
        case emptyQuery

        var errorDescription: String? {
            switch self {
            case .timeout: return "WHOIS query timed out"
            case .networkFailure: return "Network connection failed"
            case .emptyQuery: return "Query cannot be empty"
            }
        }
    }

    func configure(result: WHOISResult) {
        mockResult = result
        mockError = nil
    }

    func configureError(_ error: Error) {
        mockError = error
        mockResult = nil
    }

    func reset() {
        mockResult = nil
        mockError = nil
    }

    func lookup(query: String) async throws -> WHOISResult {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw MockError.emptyQuery
        }
        if let error = mockError {
            throw error
        }
        return mockResult ?? WHOISResult(
            query: query,
            rawData: "Mock WHOIS data for \(query)"
        )
    }
}

// MARK: - DNS Lookup Mock Tests

@Suite("Mock DNS Lookup Service Tests")
@MainActor
struct MockDNSLookupServiceTests {

    private func makeQueryResult(
        domain: String,
        recordType: DNSRecordType,
        recordValue: String,
        priority: Int? = nil
    ) -> DNSQueryResult {
        let record = DNSRecord(name: domain, type: recordType, value: recordValue, ttl: 3600, priority: priority)
        return DNSQueryResult(domain: domain, server: "mock", queryType: recordType, records: [record], queryTime: 5.0)
    }

    @Test("mock A record lookup returns configured result with IP address value")
    func mockARecordLookup() async {
        let service = MockDNSLookupService()
        service.mockResult = makeQueryResult(domain: "example.com", recordType: .a, recordValue: "93.184.216.34")

        let result = await service.lookup(domain: "example.com", recordType: .a, server: nil)

        #expect(result != nil)
        #expect(result?.domain == "example.com")
        #expect(result?.queryType == .a)
        #expect(result?.records.isEmpty == false)
        #expect(result?.records.first?.value == "93.184.216.34")
    }

    @Test("mock AAAA record lookup returns configured IPv6 result")
    func mockAAAARecordLookup() async {
        let service = MockDNSLookupService()
        service.mockResult = makeQueryResult(
            domain: "example.com",
            recordType: .aaaa,
            recordValue: "2606:2800:220:1:248:1893:25c8:1946"
        )

        let result = await service.lookup(domain: "example.com", recordType: .aaaa, server: nil)

        #expect(result?.queryType == .aaaa)
        #expect(result?.records.first?.value.contains(":") == true)
    }

    @Test("mock MX record lookup returns mail server record with priority set")
    func mockMXRecordLookup() async {
        let service = MockDNSLookupService()
        service.mockResult = makeQueryResult(
            domain: "example.com",
            recordType: .mx,
            recordValue: "mail.example.com",
            priority: 10
        )

        let result = await service.lookup(domain: "example.com", recordType: .mx, server: nil)

        #expect(result?.queryType == .mx)
        #expect(result?.records.first?.priority == 10)
        #expect(result?.records.first?.value == "mail.example.com")
    }

    @Test("mock TXT record lookup returns non-empty text record value")
    func mockTXTRecordLookup() async {
        let service = MockDNSLookupService()
        service.mockResult = makeQueryResult(
            domain: "example.com",
            recordType: .txt,
            recordValue: "v=spf1 include:_spf.example.com ~all"
        )

        let result = await service.lookup(domain: "example.com", recordType: .txt, server: nil)

        #expect(result?.queryType == .txt)
        #expect(result?.records.first?.value.isEmpty == false)
    }

    @Test("mock NS record lookup returns multiple name server hostnames")
    func mockNSRecordLookup() async {
        let service = MockDNSLookupService()
        let records = [
            DNSRecord(name: "example.com", type: .ns, value: "ns1.example.com", ttl: 86400),
            DNSRecord(name: "example.com", type: .ns, value: "ns2.example.com", ttl: 86400)
        ]
        service.mockResult = DNSQueryResult(
            domain: "example.com",
            server: "mock",
            queryType: .ns,
            records: records,
            queryTime: 5.0
        )

        let result = await service.lookup(domain: "example.com", recordType: .ns, server: nil)

        #expect(result?.queryType == .ns)
        #expect(result?.records.count == 2)
        #expect(result?.records.first?.value.contains(".") == true)
    }

    @Test("mock CNAME record lookup returns canonical name target")
    func mockCNAMERecordLookup() async {
        let service = MockDNSLookupService()
        service.mockResult = makeQueryResult(
            domain: "www.example.com",
            recordType: .cname,
            recordValue: "example.com"
        )

        let result = await service.lookup(domain: "www.example.com", recordType: .cname, server: nil)

        #expect(result?.queryType == .cname)
        #expect(result?.records.first?.value == "example.com")
    }

    @Test("configured error sets lastError and returns nil result")
    func invalidDomainSetsError() async {
        let service = MockDNSLookupService()
        service.configureError("DNS lookup failed: NXDOMAIN")

        let result = await service.lookup(domain: "invalid-domain.xyz", recordType: .a, server: nil)

        #expect(result == nil)
        #expect(service.lastError != nil)
        #expect(service.lastError?.isEmpty == false)
    }

    @Test("empty domain returns nil and sets error without reaching lookup logic")
    func emptyDomainReturnsNilWithError() async {
        let service = MockDNSLookupService()
        // Even with a mock result configured, empty domain should be rejected early
        service.mockResult = makeQueryResult(domain: "example.com", recordType: .a, recordValue: "1.1.1.1")

        let result = await service.lookup(domain: "", recordType: .a, server: nil)

        #expect(result == nil)
        #expect(service.lastError != nil)
    }

    @Test("isLoading is false before lookup and false after lookup completes")
    func loadingStateTracking() async {
        let service = MockDNSLookupService()
        service.mockResult = makeQueryResult(domain: "example.com", recordType: .a, recordValue: "93.184.216.34")

        #expect(service.isLoading == false)

        let result1 = await service.lookup(domain: "example.com", recordType: .a, server: nil)

        #expect(service.isLoading == false)
        #expect(result1 != nil)

        // Second lookup with updated mock — lastResult should reflect most recent
        service.mockResult = makeQueryResult(domain: "cloudflare.com", recordType: .a, recordValue: "1.1.1.1")
        let result2 = await service.lookup(domain: "cloudflare.com", recordType: .a, server: nil)

        #expect(service.isLoading == false)
        #expect(result2 != nil)
        #expect(service.lastResult?.domain == "cloudflare.com")
    }

    @Test("sequential lookups for multiple record types all return non-nil results")
    func multipleRecordTypesInSequence() async {
        let service = MockDNSLookupService()
        let domain = "example.com"
        let recordTypes: [DNSRecordType] = [.a, .aaaa, .mx, .txt, .ns]

        for recordType in recordTypes {
            service.mockResult = makeQueryResult(domain: domain, recordType: recordType, recordValue: "mock-value")
            let result = await service.lookup(domain: domain, recordType: recordType, server: nil)

            #expect(result != nil)
            #expect(result?.queryType == recordType)
        }
    }

    @Test("concurrent lookups on MainActor service all complete and return non-nil results")
    func concurrentLookups() async {
        let service = MockDNSLookupService()
        service.mockResult = makeQueryResult(domain: "example.com", recordType: .a, recordValue: "93.184.216.34")

        async let r1 = service.lookup(domain: "example.com", recordType: .a, server: nil)
        async let r2 = service.lookup(domain: "example.com", recordType: .a, server: nil)
        async let r3 = service.lookup(domain: "example.com", recordType: .a, server: nil)

        let (result1, result2, result3) = await (r1, r2, r3)

        #expect(result1 != nil)
        #expect(result2 != nil)
        #expect(result3 != nil)
    }
}

// MARK: - Traceroute Mock Tests

@Suite("Mock Traceroute Service Tests")
struct MockTracerouteServiceTests {

    private func syntheticHops(count: Int) -> [TracerouteHop] {
        (1...count).map { i in
            TracerouteHop(
                hopNumber: i,
                ipAddress: "10.0.0.\(i)",
                hostname: i == count ? "destination.host" : nil,
                times: [Double(i) * 2.0, Double(i) * 2.1],
                isTimeout: false
            )
        }
    }

    @Test("running state is false before trace and false after stream finishes")
    func runningStateTracking() async {
        let service = MockTracerouteService()
        await service.setMockHops(syntheticHops(count: 3))

        var isRunning = await service.running
        #expect(isRunning == false)

        let stream = await service.trace(host: "test.host", maxHops: nil, timeout: nil)
        isRunning = await service.running
        #expect(isRunning == true)

        for await _ in stream {}

        isRunning = await service.running
        #expect(isRunning == false)
    }

    @Test("trace with synthetic hops yields all hops in correct order")
    func traceWithSyntheticHops() async {
        let service = MockTracerouteService()
        await service.setMockHops(syntheticHops(count: 3))

        let stream = await service.trace(host: "8.8.8.8", maxHops: nil, timeout: nil)
        var received: [TracerouteHop] = []
        for await hop in stream {
            received.append(hop)
        }

        #expect(received.count == 3)
        #expect(received[0].hopNumber == 1)
        #expect(received[0].ipAddress == "10.0.0.1")
        #expect(received[2].hopNumber == 3)
        #expect(received[2].hostname == "destination.host")
    }

    @Test("invalid host configuration produces timeout hop in stream")
    func invalidHostHandling() async {
        let service = MockTracerouteService()
        let timeoutHop = TracerouteHop(
            hopNumber: 1,
            ipAddress: nil,
            hostname: nil,
            times: [],
            isTimeout: true
        )
        await service.setMockHops([timeoutHop])

        let stream = await service.trace(host: "definitely-not-real.invalid", maxHops: 3, timeout: nil)
        var hops: [TracerouteHop] = []
        for await hop in stream {
            hops.append(hop)
        }

        #expect(hops.count > 0)
        #expect(hops.first?.isTimeout == true)
        #expect(hops.first?.ipAddress == nil)
    }

    @Test("maxHops parameter limits the number of hops yielded from the stream")
    func maxHopsLimitsOutput() async {
        let service = MockTracerouteService()
        await service.setMockHops(syntheticHops(count: 10))

        let maxHops = 3
        let stream = await service.trace(host: "8.8.8.8", maxHops: maxHops, timeout: nil)
        var hops: [TracerouteHop] = []
        for await hop in stream {
            hops.append(hop)
        }

        #expect(hops.count <= maxHops)
    }

    @Test("stop sets running to false and allows stream to drain cleanly")
    func stopDuringTrace() async {
        let service = MockTracerouteService()
        await service.setMockHops(syntheticHops(count: 5))

        let stream = await service.trace(host: "8.8.8.8", maxHops: nil, timeout: nil)

        var isRunning = await service.running
        #expect(isRunning == true)

        await service.stop()

        isRunning = await service.running
        #expect(isRunning == false)

        // Drain any remaining buffered hops without hanging
        for await _ in stream {}
    }
}

// MARK: - WHOIS Mock Tests

@Suite("Mock WHOIS Service Tests")
struct MockWHOISServiceTests {

    @Test("mock lookup for well-known domain returns all configured parsed fields")
    func mockLookupWellKnownDomain() async throws {
        let service = MockWHOISLookupService()
        let calendar = Calendar.current
        let creation = calendar.date(byAdding: .year, value: -10, to: Date())!
        let expiration = calendar.date(byAdding: .year, value: 1, to: Date())!
        let mockResult = WHOISResult(
            query: "google.com",
            registrar: "MarkMonitor Inc.",
            creationDate: creation,
            expirationDate: expiration,
            nameServers: ["ns1.google.com", "ns2.google.com", "ns3.google.com", "ns4.google.com"],
            status: ["clientDeleteProhibited", "clientTransferProhibited"],
            rawData: "Domain Name: GOOGLE.COM\nRegistrar: MarkMonitor Inc."
        )
        await service.configure(result: mockResult)

        let result = try await service.lookup(query: "google.com")

        #expect(result.query == "google.com")
        #expect(result.registrar == "MarkMonitor Inc.")
        #expect(result.nameServers.count == 4)
        #expect(result.rawData.isEmpty == false)
        #expect(result.daysUntilExpiration != nil)
        #expect(result.daysUntilExpiration! > 0)
    }

    @Test("configured network error is thrown when performing invalid domain lookup")
    func invalidDomainHandling() async {
        let service = MockWHOISLookupService()
        await service.configureError(MockWHOISLookupService.MockError.networkFailure)

        do {
            _ = try await service.lookup(query: "invalid-domain-xyz.invalid")
            #expect(Bool(false), "Expected an error to be thrown for invalid domain")
        } catch {
            #expect(error != nil)
        }
    }

    @Test("IP address query returns result with IP preserved as query field")
    func ipAddressWHOISReturnsResult() async throws {
        let service = MockWHOISLookupService()
        let mockResult = WHOISResult(
            query: "8.8.8.8",
            rawData: "NetRange: 8.8.8.0 - 8.8.8.255\nOrganization: Google LLC"
        )
        await service.configure(result: mockResult)

        let result = try await service.lookup(query: "8.8.8.8")

        #expect(result.query == "8.8.8.8")
        #expect(result.rawData.contains("8.8.8") == true)
    }

    @Test("IP address queries use default IANA WHOIS server for server selection")
    func ipAddressUsesDefaultServer() async {
        // Tests concrete WHOISService server selection logic (no network call)
        let service = WHOISService()
        let server = await service.serverForDomain("8.8.8.8")
        // IP addresses have no TLD entry in the mapping — falls back to IANA
        #expect(server == "whois.iana.org")
    }

    @Test("configured timeout error is propagated with descriptive message")
    func timeoutHandling() async {
        let service = MockWHOISLookupService()
        await service.configureError(MockWHOISLookupService.MockError.timeout)

        do {
            _ = try await service.lookup(query: "cloudflare.com")
            #expect(Bool(false), "Expected timeout error to be thrown")
        } catch {
            let mockErr = error as? MockWHOISLookupService.MockError
            #expect(mockErr != nil)
            #expect(mockErr?.errorDescription?.contains("timed out") == true)
        }
    }

    @Test("empty query string throws error without performing any lookup")
    func emptyQueryThrows() async {
        let service = MockWHOISLookupService()
        // No mock result configured — error must come from empty-query guard
        do {
            _ = try await service.lookup(query: "")
            #expect(Bool(false), "Expected error for empty query string")
        } catch {
            #expect(error != nil)
        }
    }

    @Test("concurrent lookups on actor-isolated service all return correct results")
    func concurrentLookups() async throws {
        let service = MockWHOISLookupService()
        let mockResult = WHOISResult(
            query: "example.com",
            rawData: "Mock WHOIS data for example.com"
        )
        await service.configure(result: mockResult)

        async let r1 = service.lookup(query: "example.com")
        async let r2 = service.lookup(query: "example.com")
        async let r3 = service.lookup(query: "example.com")

        let (result1, result2, result3) = try await (r1, r2, r3)

        #expect(result1.query == "example.com")
        #expect(result2.query == "example.com")
        #expect(result3.query == "example.com")
    }
}
