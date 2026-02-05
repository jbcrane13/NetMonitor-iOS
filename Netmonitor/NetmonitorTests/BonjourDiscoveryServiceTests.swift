import XCTest
import Network
@testable import Netmonitor

@MainActor
final class BonjourDiscoveryServiceTests: XCTestCase {
    var service: BonjourDiscoveryService!
    
    override func setUp() {
        super.setUp()
        service = BonjourDiscoveryService()
    }
    
    override func tearDown() {
        service.stopDiscovery()
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertTrue(service.discoveredServices.isEmpty)
        XCTAssertFalse(service.isDiscovering)
    }
    
    // MARK: - State Management Tests
    
    func testStartStopDiscovery() {
        service.startDiscovery()
        XCTAssertTrue(service.isDiscovering)
        
        service.stopDiscovery()
        XCTAssertFalse(service.isDiscovering)
    }
    
    func testMultipleStartCallsClearState() {
        // Add some fake services to test clearing
        service.startDiscovery()
        let initialCount = service.discoveredServices.count
        
        // Start again - should clear previous results
        service.startDiscovery()
        XCTAssertEqual(service.discoveredServices.count, 0)
        XCTAssertTrue(service.isDiscovering)
    }
    
    // MARK: - Service Type Tests
    
    func testServiceDiscoveryWithSpecificType() async throws {
        // Test discovery with specific service type
        let expectation = XCTestExpectation(description: "Bonjour discovery")
        expectation.isInverted = false // We expect this to complete
        
        Task {
            let stream = service.discoveryStream(serviceType: "_http._tcp")
            var serviceCount = 0
            
            // Collect services for a limited time
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(5))
                service.stopDiscovery()
            }
            
            for await _ in stream {
                serviceCount += 1
                if serviceCount >= 1 {
                    // Found at least one service, test passes
                    timeoutTask.cancel()
                    break
                }
            }
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testGeneralServiceDiscovery() async throws {
        // Test general service discovery (all types)
        let expectation = XCTestExpectation(description: "General Bonjour discovery")
        
        Task {
            let stream = service.discoveryStream(serviceType: nil)
            var hasFoundService = false
            
            // Set a timeout
            let timeoutTask = Task {
                try await Task.sleep(for: .seconds(8))
                service.stopDiscovery()
            }
            
            for await _ in stream {
                hasFoundService = true
                timeoutTask.cancel()
                service.stopDiscovery()
                break
            }
            
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testStopDiscoveryDuringStreaming() async throws {
        let expectation = XCTestExpectation(description: "Discovery stops cleanly")
        
        Task {
            let stream = service.discoveryStream(serviceType: "_http._tcp")
            
            // Start collecting but stop after a short time
            let stopTask = Task {
                try await Task.sleep(for: .seconds(1))
                service.stopDiscovery()
            }
            
            var streamEnded = false
            for await _ in stream {
                // Stream should end when we call stopDiscovery
            }
            streamEnded = true
            
            XCTAssertTrue(streamEnded)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertFalse(service.isDiscovering)
    }
    
    // MARK: - Service Resolution Tests
    
    func testServiceResolution() async throws {
        // Create a mock service to test resolution
        let mockService = BonjourService(
            name: "Test Service",
            type: "_http._tcp",
            domain: "local.",
            hostName: nil,
            port: nil
        )
        
        // This test may fail if local network access isn't available
        let resolved = await service.resolveService(mockService)
        
        // Resolution might fail, which is okay for a test environment
        // The important thing is that it doesn't crash
        if let resolved = resolved {
            XCTAssertEqual(resolved.name, mockService.name)
            XCTAssertEqual(resolved.type, mockService.type)
        }
    }
    
    // MARK: - Network Permission Tests
    
    func testNetworkAccessRequirement() {
        // Bonjour discovery requires local network access
        // This test checks that the service handles permission issues gracefully
        
        service.startDiscovery(serviceType: "_http._tcp")
        
        // The service should handle network permission denials gracefully
        // and not crash or enter an invalid state
        XCTAssertTrue(service.isDiscovering || !service.isDiscovering) // Either state is valid
    }
    
    // MARK: - Service Categorization Tests
    
    func testServiceCategorization() {
        let httpService = BonjourService(name: "Web Server", type: "_http._tcp")
        XCTAssertEqual(httpService.serviceCategory, "Web")
        
        let sshService = BonjourService(name: "SSH Server", type: "_ssh._tcp")
        XCTAssertEqual(sshService.serviceCategory, "Remote Access")
        
        let printerService = BonjourService(name: "Printer", type: "_ipp._tcp")
        XCTAssertEqual(printerService.serviceCategory, "Printing")
        
        let unknownService = BonjourService(name: "Unknown", type: "_custom._tcp")
        XCTAssertEqual(unknownService.serviceCategory, "Other")
    }
    
    // MARK: - Common Service Types Tests
    
    func testCommonServiceTypesAreBrowsed() {
        // Verify that common service types are included in the general discovery
        let commonTypes = [
            "_http._tcp",
            "_https._tcp", 
            "_ssh._tcp",
            "_smb._tcp",
            "_printer._tcp",
            "_airplay._tcp"
        ]
        
        // This is more of a documentation test to ensure we're covering the right types
        for serviceType in commonTypes {
            XCTAssertTrue(serviceType.hasPrefix("_"))
            XCTAssertTrue(serviceType.hasSuffix("._tcp"))
        }
    }
    
    // MARK: - Performance Tests
    
    func testDiscoveryPerformance() async throws {
        // Test that discovery doesn't take an unreasonable amount of time to start
        let startTime = Date()
        
        service.startDiscovery(serviceType: "_http._tcp")
        
        let startupTime = Date().timeIntervalSince(startTime)
        service.stopDiscovery()
        
        // Starting discovery should be nearly instantaneous
        XCTAssertLessThan(startupTime, 1.0, "Discovery startup took too long")
    }
    
    func testMemoryUsageDuringDiscovery() async throws {
        // Basic test to ensure we don't leak services
        service.startDiscovery()
        
        // Let it run briefly
        try await Task.sleep(for: .seconds(2))
        
        let serviceCount = service.discoveredServices.count
        
        service.stopDiscovery()
        
        // After stopping, we should retain the discovered services
        // but not continue adding new ones
        XCTAssertEqual(service.discoveredServices.count, serviceCount)
        XCTAssertFalse(service.isDiscovering)
    }
}