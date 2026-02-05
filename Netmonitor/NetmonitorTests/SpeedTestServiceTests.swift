import XCTest
@testable import Netmonitor

@MainActor
final class SpeedTestServiceTests: XCTestCase {
    var service: SpeedTestService!
    
    override func setUp() {
        super.setUp()
        service = SpeedTestService()
    }
    
    override func tearDown() {
        service.stopTest()
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertEqual(service.downloadSpeed, 0)
        XCTAssertEqual(service.uploadSpeed, 0)
        XCTAssertEqual(service.latency, 0)
        XCTAssertEqual(service.progress, 0)
        XCTAssertEqual(service.phase, .idle)
        XCTAssertFalse(service.isRunning)
        XCTAssertNil(service.errorMessage)
    }
    
    // MARK: - URL Tests
    
    func testDownloadURLIsValid() {
        // Test that the download URL is properly formed and accessible
        let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")
        XCTAssertNotNil(downloadURL)
        XCTAssertEqual(downloadURL?.scheme, "https")
        XCTAssertEqual(downloadURL?.host, "speed.cloudflare.com")
        XCTAssertEqual(downloadURL?.path, "/__down")
        XCTAssertEqual(downloadURL?.query, "bytes=25000000")
    }
    
    func testUploadURLIsValid() {
        let uploadURL = URL(string: "https://speed.cloudflare.com/__up")
        XCTAssertNotNil(uploadURL)
        XCTAssertEqual(uploadURL?.scheme, "https")
        XCTAssertEqual(uploadURL?.host, "speed.cloudflare.com")
        XCTAssertEqual(uploadURL?.path, "/__up")
    }
    
    // MARK: - State Management Tests
    
    func testStopTestChangesState() {
        service.stopTest()
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(service.phase, .idle)
    }
    
    // MARK: - Progress Tests
    
    func testProgressStaysInValidRange() async throws {
        // This test will fail with current implementation due to byte-by-byte processing
        let expectation = XCTestExpectation(description: "Speed test completes or fails")
        
        Task {
            do {
                _ = try await service.startTest()
                expectation.fulfill()
            } catch {
                // Test should complete even if it fails
                expectation.fulfill()
            }
        }
        
        // Monitor progress values
        var invalidProgressDetected = false
        for _ in 0..<50 {
            try await Task.sleep(for: .milliseconds(100))
            if service.progress < 0 || service.progress > 1 {
                invalidProgressDetected = true
                break
            }
            if service.phase == .complete {
                break
            }
        }
        
        service.stopTest()
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // This should pass once we fix the byte counting
        XCTAssertFalse(invalidProgressDetected, "Progress should stay between 0 and 1")
    }
    
    // MARK: - Performance Tests
    
    func testDownloadPerformance() async throws {
        // This test will expose the inefficient byte-by-byte processing
        let startTime = Date()
        
        let expectation = XCTestExpectation(description: "Download test")
        Task {
            do {
                _ = try await service.startTest()
            } catch {
                // Ignore network errors for this performance test
            }
            expectation.fulfill()
        }
        
        // Wait max 30 seconds
        await fulfillment(of: [expectation], timeout: 30.0)
        
        let duration = Date().timeIntervalSince(startTime)
        
        // A 25MB download should not take more than 20 seconds on any reasonable connection
        // The current byte-by-byte implementation might make this fail
        XCTAssertLessThan(duration, 20.0, "Download test took too long - may indicate inefficient processing")
    }
    
    // MARK: - Error Handling Tests
    
    func testStopTestDuringExecution() async throws {
        let expectation = XCTestExpectation(description: "Test stops properly")
        
        Task {
            do {
                _ = try await service.startTest()
            } catch is CancellationError {
                // Expected when we stop the test
                expectation.fulfill()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        // Wait a bit then stop
        try await Task.sleep(for: .milliseconds(500))
        service.stopTest()
        
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertFalse(service.isRunning)
        XCTAssertEqual(service.phase, .idle)
    }
    
    // MARK: - Data Consistency Tests
    
    func testSpeedCalculationConsistency() async throws {
        // Test that the speed calculations make sense
        // This might fail with current implementation due to calculation bugs
        
        let expectation = XCTestExpectation(description: "Speed test calculation")
        
        Task {
            do {
                let result = try await service.startTest()
                
                // Basic sanity checks
                XCTAssertGreaterThanOrEqual(result.downloadSpeed, 0)
                XCTAssertGreaterThanOrEqual(result.uploadSpeed, 0)
                XCTAssertGreaterThanOrEqual(result.latency, 0)
                
                // Speed should be reasonable (not impossibly high or negative)
                XCTAssertLessThan(result.downloadSpeed, 10000) // < 10 Gbps (reasonable upper bound)
                XCTAssertLessThan(result.uploadSpeed, 10000)   // < 10 Gbps (reasonable upper bound)
                XCTAssertLessThan(result.latency, 5000)        // < 5 seconds (reasonable upper bound)
                
                expectation.fulfill()
            } catch {
                // Network errors are acceptable for this test
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 30.0)
    }
}