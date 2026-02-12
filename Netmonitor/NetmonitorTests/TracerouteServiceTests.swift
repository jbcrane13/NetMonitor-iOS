import Testing
@testable import Netmonitor

@Suite("TracerouteService Tests")
struct TracerouteServiceTests {

    @Test("Service initializes correctly")
    func serviceInitialization() async {
        let service = TracerouteService()
        #expect(await service.running == false)
    }

    @Test("Service sets running state correctly", .disabled("Requires live network — integration test"))
    func runningState() async {
        let service = TracerouteService()
        
        // Create a trace that will run briefly
        let stream = await service.trace(host: "127.0.0.1", maxHops: 1, timeout: 0.1)
        
        // Give it a moment to start
        try? await Task.sleep(for: .milliseconds(10))
        #expect(await service.running == true)
        
        // Stop the service
        await service.stop()
        #expect(await service.running == false)
        
        // Consume the stream to complete
        var hops: [TracerouteHop] = []
        for await hop in stream {
            hops.append(hop)
            if hops.count >= 5 { break } // Prevent infinite waiting
        }
    }

    @Test("Trace localhost produces results", .disabled("Requires live network — integration test"))
    func traceLocalhost() async {
        let service = TracerouteService()
        let stream = await service.trace(host: "127.0.0.1", maxHops: 5, timeout: 0.5)
        
        var hops: [TracerouteHop] = []
        var hopCount = 0
        
        for await hop in stream {
            hops.append(hop)
            hopCount += 1
            #expect(hop.hopNumber > 0)
            #expect(hop.hopNumber <= 5)
            
            if hopCount >= 5 { break }
        }
        
        #expect(hops.count > 0)
        // Should eventually reach localhost
        #expect(hops.contains { !$0.isTimeout })
    }

    @Test("Trace invalid hostname handles gracefully", .disabled("Requires live network — integration test"))
    func traceInvalidHost() async {
        let service = TracerouteService()
        let stream = await service.trace(host: "definitely-not-a-real-host-12345.invalid", maxHops: 3, timeout: 0.2)
        
        var hops: [TracerouteHop] = []
        
        for await hop in stream {
            hops.append(hop)
            if hops.count >= 5 { break }
        }
        
        // Should produce at least one result (even if it's a failure)
        #expect(hops.count > 0)
        // First hop should be a timeout or have no IP
        if let firstHop = hops.first {
            #expect(firstHop.isTimeout == true || firstHop.ipAddress == nil)
        }
    }

    @Test("Trace respects max hops limit", .disabled("Requires live network — integration test"))
    func traceMaxHops() async {
        let service = TracerouteService()
        let maxHops = 3
        let stream = await service.trace(host: "8.8.8.8", maxHops: maxHops, timeout: 0.1)
        
        var hops: [TracerouteHop] = []
        
        for await hop in stream {
            hops.append(hop)
            #expect(hop.hopNumber <= maxHops)
            
            if hops.count >= maxHops + 2 { break } // Allow some extra buffer
        }
        
        // Should not exceed max hops significantly
        #expect(hops.count <= maxHops + 1)
    }

    @Test("Hop numbers are sequential", .disabled("Requires live network — integration test"))
    func hopSequentialNumbers() async {
        let service = TracerouteService()
        let stream = await service.trace(host: "127.0.0.1", maxHops: 3, timeout: 0.2)
        
        var hops: [TracerouteHop] = []
        
        for await hop in stream {
            hops.append(hop)
            if hops.count >= 5 { break }
        }
        
        // Verify hop numbers are sequential
        for (index, hop) in hops.enumerated() {
            #expect(hop.hopNumber == index + 1)
        }
    }

    @Test("Stop function works during operation", .disabled("Requires live network — integration test"))
    func stopDuringTrace() async {
        let service = TracerouteService()
        let stream = await service.trace(host: "8.8.8.8", maxHops: 30, timeout: 2.0)
        
        var hops: [TracerouteHop] = []
        
        let stopTask = Task { @Sendable in
            try? await Task.sleep(for: .milliseconds(100))
            await service.stop()
        }
        
        for await hop in stream {
            hops.append(hop)
            if hops.count >= 10 { break } // Safety limit
        }
        
        // Wait for stop task to complete
        await stopTask.value
        #expect(hops.count < 30) // Should not complete full trace
    }

    @Test("TracerouteHop model properties work correctly")
    func hopModelProperties() async {
        // Test with a successful hop
        let successHop = TracerouteHop(
            hopNumber: 1,
            ipAddress: "192.168.1.1",
            hostname: "router.local",
            times: [15.5, 16.2, 14.8],
            isTimeout: false
        )
        
        #expect(successHop.displayAddress == "router.local")
        #expect(successHop.averageTime == 15.5)
        #expect(successHop.timeText == "15.5 ms")
        #expect(successHop.isTimeout == false)
        
        // Test with a timeout hop
        let timeoutHop = TracerouteHop(
            hopNumber: 2,
            ipAddress: nil,
            hostname: nil,
            times: [],
            isTimeout: true
        )
        
        #expect(timeoutHop.displayAddress == "*")
        #expect(timeoutHop.averageTime == nil)
        #expect(timeoutHop.timeText == "*")
        #expect(timeoutHop.isTimeout == true)
        
        // Test with IP only
        let ipOnlyHop = TracerouteHop(
            hopNumber: 3,
            ipAddress: "203.0.113.1",
            hostname: nil,
            times: [25.0],
            isTimeout: false
        )
        
        #expect(ipOnlyHop.displayAddress == "203.0.113.1")
        #expect(ipOnlyHop.averageTime == 25.0)
        #expect(ipOnlyHop.timeText == "25.0 ms")
    }
}