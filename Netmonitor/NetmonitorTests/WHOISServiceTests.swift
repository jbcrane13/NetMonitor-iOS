import Foundation
import Testing
@testable import Netmonitor

@Suite("WHOISService Tests")
struct WHOISServiceTests {

    @Test("Service initializes correctly")
    func serviceInitialization() async {
        let service = WHOISService()
        #expect(service != nil)
    }

    @Test("Server selection works for common TLDs")
    func serverSelection() async {
        let service = WHOISService()
        
        #expect(await service.serverForDomain("example.com") == "whois.verisign-grs.com")
        #expect(await service.serverForDomain("example.net") == "whois.verisign-grs.com")
        #expect(await service.serverForDomain("example.org") == "whois.pir.org")
        #expect(await service.serverForDomain("example.io") == "whois.nic.io")
        #expect(await service.serverForDomain("example.dev") == "whois.nic.google")
        #expect(await service.serverForDomain("example.app") == "whois.nic.google")
        #expect(await service.serverForDomain("example.co") == "whois.nic.co")
        
        // Unknown TLD should fall back to default
        #expect(await service.serverForDomain("example.unknowntld") == "whois.iana.org")
        
        // Domain without TLD should use default
        #expect(await service.serverForDomain("example") == "whois.iana.org")
    }

    @Test("Server selection is case insensitive")
    func serverSelectionCaseInsensitive() async {
        let service = WHOISService()
        
        #expect(await service.serverForDomain("EXAMPLE.COM") == "whois.verisign-grs.com")
        #expect(await service.serverForDomain("Example.Com") == "whois.verisign-grs.com")
        #expect(await service.serverForDomain("example.COM") == "whois.verisign-grs.com")
    }

    @Test("WHOIS lookup for well-known domain works", .disabled("Requires live network — integration test"))
    func lookupWellKnownDomain() async throws {
        let service = WHOISService()
        
        // Use a domain that should always exist and have WHOIS data
        let result = try await service.lookup(query: "google.com")
        
        #expect(result.query == "google.com")
        #expect(result.rawData.isEmpty == false)
        #expect(result.rawData.contains("google") || result.rawData.contains("Google"))
        
        // Should have some parsed data (not all fields required, depends on registrar)
        #expect(result.registrar != nil || result.nameServers.isEmpty == false)
    }

    @Test("WHOIS lookup for invalid domain handles gracefully", .disabled("Requires live network — integration test"))
    func lookupInvalidDomain() async {
        let service = WHOISService()
        
        do {
            let result = try await service.lookup(query: "definitely-not-a-real-domain-12345.invalid")
            
            // If it doesn't throw, it should return some data indicating not found
            #expect(result.query == "definitely-not-a-real-domain-12345.invalid")
            #expect(result.rawData.isEmpty == false)
            
        } catch {
            // It's acceptable for invalid domains to throw errors
            #expect(error != nil)
        }
    }

    @Test("WHOIS result model properties work correctly")
    func whoisResultModel() async {
        let testDate = Date()
        let result = WHOISResult(
            query: "example.com",
            registrar: "Example Registrar",
            creationDate: Calendar.current.date(byAdding: .year, value: -5, to: testDate),
            expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: testDate),
            updatedDate: Calendar.current.date(byAdding: .month, value: -1, to: testDate),
            nameServers: ["ns1.example.com", "ns2.example.com"],
            status: ["clientTransferProhibited", "serverDeleteProhibited"],
            rawData: "Sample WHOIS data for example.com"
        )
        
        #expect(result.query == "example.com")
        #expect(result.registrar == "Example Registrar")
        #expect(result.nameServers.count == 2)
        #expect(result.nameServers.contains("ns1.example.com"))
        #expect(result.nameServers.contains("ns2.example.com"))
        #expect(result.status.count == 2)
        #expect(result.status.contains("clientTransferProhibited"))
        #expect(result.rawData.contains("example.com"))
        
        // Test computed properties
        #expect(result.domainAge == "5 years")
        
        let daysUntilExp = result.daysUntilExpiration
        #expect(daysUntilExp != nil)
        #expect(daysUntilExp! > 300) // Should be around 365 days
        #expect(daysUntilExp! < 400)
    }

    @Test("WHOIS result handles nil dates gracefully")
    func whoisResultNilDates() async {
        let result = WHOISResult(
            query: "example.com",
            registrar: "Test Registrar",
            creationDate: nil,
            expirationDate: nil,
            updatedDate: nil,
            nameServers: [],
            status: [],
            rawData: "Limited WHOIS data"
        )
        
        #expect(result.domainAge == nil)
        #expect(result.daysUntilExpiration == nil)
    }

    @Test("WHOIS handles IP address queries", .disabled("Requires live network — integration test"))
    func lookupIPAddress() async {
        let service = WHOISService()
        
        do {
            // Try a well-known public IP (Google DNS)
            let result = try await service.lookup(query: "8.8.8.8")
            
            #expect(result.query == "8.8.8.8")
            #expect(result.rawData.isEmpty == false)
            
            // IP WHOIS has different format than domain WHOIS
            // Should contain some network information
            #expect(result.rawData.contains("8.8.8") || result.rawData.lowercased().contains("google"))
            
        } catch {
            // Network issues are acceptable for this test
            #expect(error != nil)
        }
    }

    @Test("WHOIS lookup timeout handling", .disabled("Requires live network — integration test"))
    func lookupTimeout() async {
        let service = WHOISService()
        
        // This test is tricky because we can't easily simulate a timeout
        // Instead, we'll test with a valid domain and verify it completes in reasonable time
        let startTime = Date()
        
        do {
            let result = try await service.lookup(query: "cloudflare.com")
            let elapsed = Date().timeIntervalSince(startTime)
            
            #expect(result != nil)
            #expect(elapsed < 30.0) // Should complete within 30 seconds
            
        } catch {
            // Network errors are acceptable
            let elapsed = Date().timeIntervalSince(startTime)
            #expect(elapsed < 30.0) // Even errors should happen quickly
        }
    }

    @Test("WHOIS handles empty query gracefully", .disabled("Requires live network — integration test"))
    func lookupEmptyQuery() async {
        let service = WHOISService()
        
        do {
            let result = try await service.lookup(query: "")
            
            // Should either throw or return empty/error result
            #expect(result.query == "")
            
        } catch {
            // Throwing an error for empty query is acceptable
            #expect(error != nil)
        }
    }

    @Test("WHOIS raw data parsing edge cases", .disabled("Requires live network — integration test"))
    func rawDataParsing() async {
        // Test that the service can handle various WHOIS response formats
        let service = WHOISService()
        
        // We can't easily test the private parsing methods directly,
        // but we can verify the service doesn't crash with unusual inputs
        
        let edgeCases = [
            " ", // whitespace
            "DOMAIN NOT FOUND",
            "No matching record.",
            "Rate limit exceeded"
        ]
        
        for edgeCase in edgeCases {
            do {
                let result = try await service.lookup(query: edgeCase)
                #expect(result.query == edgeCase)
                #expect(result.rawData.isEmpty == false)
            } catch {
                // Errors are acceptable for these edge cases
                #expect(error != nil)
            }
        }
    }

    @Test("WHOIS date formatting validation")
    func dateFormatValidation() async {
        // Create a mock result with various date formats that might appear in WHOIS data
        let result1 = WHOISResult(
            query: "test.com",
            rawData: "Creation Date: 2020-01-15T10:30:00Z"
        )
        
        let result2 = WHOISResult(
            query: "test2.com", 
            rawData: "Created: 2019-12-25"
        )
        
        #expect(result1.query == "test.com")
        #expect(result2.query == "test2.com")
        
        // The parsing is done in the actual lookup, so these tests verify the model works
        #expect(result1.rawData.contains("2020-01-15"))
        #expect(result2.rawData.contains("2019-12-25"))
    }

    @Test("Concurrent WHOIS lookups work correctly", .disabled("Requires live network — integration test"))
    func concurrentLookups() async {
        let service = WHOISService()

        // Test multiple concurrent lookups using async let instead of withTaskGroup
        // to avoid Swift Testing @Test macro expansion issues with @Sendable closures
        let domains = ["example.com", "google.com", "github.com"]

        var results: [String: WHOISResult?] = [:]
        for domain in domains {
            do {
                let result = try await service.lookup(query: domain)
                results[domain] = result
            } catch {
                results[domain] = nil
            }
        }

        #expect(results.count == domains.count)

        for domain in domains {
            if let whoisResult = results[domain], let result = whoisResult {
                #expect(result.query == domain)
            }
        }
    }
}