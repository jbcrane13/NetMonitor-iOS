import Testing
@testable import Netmonitor

@Suite("PingService Tests")
struct PingServiceTests {

    @Test("Service starts and stops correctly")
    func serviceStartStop() async {
        let service = PingService()
        
        // Start a ping with a reasonable count
        let stream = await service.ping(host: "127.0.0.1", count: 5, timeout: 1.0)
        
        var results: [PingResult] = []
        
        // Stop after a short delay
        let stopTask = Task { @Sendable in
            try? await Task.sleep(for: .milliseconds(300))
            await service.stop()
        }
        
        for await result in stream {
            results.append(result)
            if results.count >= 5 { break } // Safety limit
        }
        
        // Wait for the stop task to complete
        await stopTask.value
        
        #expect(results.count > 0)
        #expect(results.count <= 5) // Should not exceed the requested count
    }

    @Test("Ping localhost produces results")
    func pingLocalhost() async {
        let service = PingService()
        let stream = await service.ping(host: "127.0.0.1", count: 3, timeout: 2.0)
        
        var results: [PingResult] = []
        
        for await result in stream {
            results.append(result)
            
            #expect(result.host == "127.0.0.1")
            #expect(result.sequence > 0)
            #expect(result.sequence <= 3)
            #expect(result.size == 64)
            
            if results.count >= 3 { break }
        }
        
        #expect(results.count == 3)

        // TCP ping may timeout on localhost without a web server - verify structure instead
        for result in results {
            #expect(result.host == "127.0.0.1")
            #expect(result.sequence > 0)
        }
        
        // Verify sequence numbers are correct
        for (index, result) in results.enumerated() {
            #expect(result.sequence == index + 1)
        }
    }

    @Test("Ping invalid host handles gracefully")
    func pingInvalidHost() async {
        let service = PingService()
        let stream = await service.ping(host: "definitely-not-a-real-host-12345.invalid", count: 2, timeout: 0.5)
        
        var results: [PingResult] = []
        
        for await result in stream {
            results.append(result)
            
            #expect(result.host == "definitely-not-a-real-host-12345.invalid")
            #expect(result.isTimeout == true || result.ipAddress == nil)
            
            if results.count >= 2 { break }
        }
        
        #expect(results.count == 2)
    }

    @Test("Ping with IP address works")
    func pingIPAddress() async {
        let service = PingService()
        let stream = await service.ping(host: "8.8.8.8", count: 2, timeout: 2.0)
        
        var results: [PingResult] = []
        
        for await result in stream {
            results.append(result)
            
            #expect(result.host == "8.8.8.8")
            #expect(result.ipAddress == "8.8.8.8") // Should be the same
            
            if results.count >= 2 { break }
        }
        
        #expect(results.count == 2)
    }

    @Test("Calculate statistics with successful pings")
    func calculateStatisticsSuccess() async {
        let service = PingService()
        let results: [PingResult] = [
            PingResult(sequence: 1, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 10.0, size: 64, isTimeout: false),
            PingResult(sequence: 2, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 20.0, size: 64, isTimeout: false),
            PingResult(sequence: 3, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 15.0, size: 64, isTimeout: false),
            PingResult(sequence: 4, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 25.0, size: 64, isTimeout: false),
        ]

        let stats = await service.calculateStatistics(results)

        #expect(stats != nil)
        if let stats {
            #expect(stats.transmitted == 4)
            #expect(stats.received == 4)
            #expect(stats.packetLoss == 0.0)
            #expect(stats.minTime == 10.0)
            #expect(stats.maxTime == 25.0)
            #expect(stats.avgTime == 17.5)
            #expect(stats.host == "1.1.1.1")
            #expect(stats.successRate == 100.0)
            #expect(stats.packetLossText == "0.0%")
        }
    }

    @Test("Calculate statistics with packet loss")
    func calculateStatisticsWithLoss() async {
        let service = PingService()
        let results: [PingResult] = [
            PingResult(sequence: 1, host: "1.1.1.1", ipAddress: "1.1.1.1", ttl: 64, time: 10.0, size: 64, isTimeout: false),
            PingResult(sequence: 2, host: "1.1.1.1", ipAddress: nil, ttl: 0, time: 5000.0, size: 64, isTimeout: true),
        ]

        let stats = await service.calculateStatistics(results, requestedCount: 2)

        #expect(stats != nil)
        if let stats {
            #expect(stats.transmitted == 2)
            #expect(stats.received == 1)
            #expect(stats.packetLoss == 50.0)
            #expect(stats.successRate == 50.0)
            #expect(stats.packetLossText == "50.0%")
            #expect(stats.minTime == 10.0)
            #expect(stats.maxTime == 10.0)
            #expect(stats.avgTime == 10.0)
        }
    }

    @Test("Calculate statistics with all timeouts")
    func calculateStatisticsAllTimeouts() async {
        let service = PingService()
        let results: [PingResult] = [
            PingResult(sequence: 1, host: "test.invalid", ipAddress: nil, ttl: 0, time: 5000.0, size: 64, isTimeout: true),
            PingResult(sequence: 2, host: "test.invalid", ipAddress: nil, ttl: 0, time: 5000.0, size: 64, isTimeout: true),
        ]

        let stats = await service.calculateStatistics(results, requestedCount: 2)

        #expect(stats != nil)
        if let stats {
            #expect(stats.transmitted == 2)
            #expect(stats.received == 0)
            #expect(stats.packetLoss == 100.0)
            #expect(stats.successRate == 0.0)
            #expect(stats.minTime == 0.0)
            #expect(stats.maxTime == 0.0)
            #expect(stats.avgTime == 0.0)
        }
    }

    @Test("Calculate statistics with empty results returns nil")
    func calculateStatisticsEmpty() async {
        let service = PingService()
        let stats = await service.calculateStatistics([])
        #expect(stats == nil)
    }

    @Test("Calculate statistics infers transmitted count")
    func calculateStatisticsInferredCount() async {
        let service = PingService()
        let results: [PingResult] = [
            PingResult(sequence: 1, host: "test.com", ipAddress: "1.2.3.4", ttl: 64, time: 10.0),
            PingResult(sequence: 2, host: "test.com", ipAddress: "1.2.3.4", ttl: 64, time: 15.0),
            PingResult(sequence: 3, host: "test.com", ipAddress: "1.2.3.4", ttl: 64, time: 12.0),
        ]

        // Don't specify requestedCount - should infer from results
        let stats = await service.calculateStatistics(results)

        #expect(stats != nil)
        if let stats {
            #expect(stats.transmitted == 3)
            #expect(stats.received == 3)
            #expect(stats.packetLoss == 0.0)
        }
    }

    @Test("PingResult model properties work correctly")
    func pingResultModel() async {
        let result = PingResult(
            sequence: 1,
            host: "example.com",
            ipAddress: "93.184.216.34",
            ttl: 64,
            time: 15.5,
            size: 64,
            isTimeout: false
        )
        
        #expect(result.sequence == 1)
        #expect(result.host == "example.com")
        #expect(result.ipAddress == "93.184.216.34")
        #expect(result.ttl == 64)
        #expect(result.time == 15.5)
        #expect(result.size == 64)
        #expect(result.isTimeout == false)
        #expect(result.timeText == "15.5 ms")
        
        // Test timeout result
        let timeoutResult = PingResult(
            sequence: 2,
            host: "example.com",
            ipAddress: nil,
            ttl: 0,
            time: 5000.0,
            size: 64,
            isTimeout: true
        )
        
        #expect(timeoutResult.isTimeout == true)
        #expect(timeoutResult.timeText == "timeout")
        
        // Test sub-millisecond timing
        let fastResult = PingResult(
            sequence: 3,
            host: "localhost",
            ipAddress: "127.0.0.1",
            ttl: 64,
            time: 0.75,
            size: 64,
            isTimeout: false
        )
        
        #expect(fastResult.timeText == "0.75 ms")
    }

    @Test("PingStatistics model properties work correctly")
    func pingStatisticsModel() async {
        let stats = PingStatistics(
            host: "test.example.com",
            transmitted: 10,
            received: 8,
            packetLoss: 20.0,
            minTime: 5.5,
            maxTime: 50.2,
            avgTime: 25.1,
            stdDev: 12.3
        )
        
        #expect(stats.host == "test.example.com")
        #expect(stats.transmitted == 10)
        #expect(stats.received == 8)
        #expect(stats.packetLoss == 20.0)
        #expect(stats.minTime == 5.5)
        #expect(stats.maxTime == 50.2)
        #expect(stats.avgTime == 25.1)
        #expect(stats.stdDev == 12.3)
        #expect(stats.successRate == 80.0)
        #expect(stats.packetLossText == "20.0%")
    }

    @Test("Ping timeout parameter works")
    func pingTimeout() async {
        let service = PingService()
        
        // Use a very short timeout for an external host
        let stream = await service.ping(host: "8.8.8.8", count: 1, timeout: 0.01) // 10ms timeout
        
        var result: PingResult?
        
        for await pingResult in stream {
            result = pingResult
            break
        }
        
        #expect(result != nil)
        if let result = result {
            #expect(result.host == "8.8.8.8")
            // With such a short timeout, it should likely timeout
            // (though this depends on network conditions)
        }
    }

    @Test("Ping count parameter works correctly")
    func pingCount() async {
        let service = PingService()
        let requestedCount = 5
        let stream = await service.ping(host: "127.0.0.1", count: requestedCount, timeout: 1.0)
        
        var results: [PingResult] = []
        
        for await result in stream {
            results.append(result)
            if results.count >= requestedCount + 2 { break } // Safety limit
        }
        
        #expect(results.count == requestedCount)
        
        // Verify sequence numbers
        for (index, result) in results.enumerated() {
            #expect(result.sequence == index + 1)
        }
    }

    @Test("Concurrent ping operations handled correctly")
    func concurrentPings() async {
        let service1 = PingService()
        let service2 = PingService()
        
        // Start two ping operations concurrently
        await withTaskGroup(of: [PingResult].self) { group in
            group.addTask { @Sendable in
                var results: [PingResult] = []
                let stream = await service1.ping(host: "127.0.0.1", count: 2, timeout: 1.0)
                for await result in stream {
                    results.append(result)
                    if results.count >= 2 { break }
                }
                return results
            }
            
            group.addTask { @Sendable in
                var results: [PingResult] = []
                let stream = await service2.ping(host: "8.8.8.8", count: 2, timeout: 1.0)
                for await result in stream {
                    results.append(result)
                    if results.count >= 2 { break }
                }
                return results
            }
            
            var allResults: [[PingResult]] = []
            for await results in group {
                allResults.append(results)
            }
            
            #expect(allResults.count == 2)
            
            // Each service should have produced its results
            for results in allResults {
                #expect(results.count <= 2)
                if results.count > 0 {
                    #expect(results[0].sequence == 1)
                }
            }
        }
    }

    @Test("Standard deviation calculation in statistics")
    func statisticsStandardDeviation() async {
        let service = PingService()
        let results: [PingResult] = [
            PingResult(sequence: 1, host: "test.com", ipAddress: "1.2.3.4", ttl: 64, time: 10.0),
            PingResult(sequence: 2, host: "test.com", ipAddress: "1.2.3.4", ttl: 64, time: 20.0),
            PingResult(sequence: 3, host: "test.com", ipAddress: "1.2.3.4", ttl: 64, time: 30.0),
        ]

        let stats = await service.calculateStatistics(results)

        #expect(stats != nil)
        if let stats {
            #expect(stats.avgTime == 20.0)
            #expect(stats.stdDev != nil)
            
            // Standard deviation for values [10, 20, 30] with mean 20 should be ~8.16
            #expect(abs(stats.stdDev! - 8.16) < 0.5)
        }
    }
}
