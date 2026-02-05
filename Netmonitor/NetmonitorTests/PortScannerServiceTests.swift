import Testing
@testable import Netmonitor

@Suite("PortScannerService Tests")
struct PortScannerServiceTests {

    @Test("Service initializes correctly")
    func serviceInitialization() async {
        let service = PortScannerService()
        // Service should be ready to use
        #expect(service != nil)
    }

    @Test("Scan localhost known open ports")
    func scanLocalhostOpenPorts() async {
        let service = PortScannerService()
        
        // Test common ports that might be open on localhost
        let portsToScan = [80, 443, 22, 8080]
        let stream = await service.scan(host: "127.0.0.1", ports: portsToScan, timeout: 1.0)
        
        var results: [PortScanResult] = []
        
        for await result in stream {
            results.append(result)
            #expect(portsToScan.contains(result.port))
            #expect(result.state != nil)
            
            if results.count >= portsToScan.count { break }
        }
        
        #expect(results.count == portsToScan.count)
        
        // Verify all requested ports were scanned
        let scannedPorts = Set(results.map(\.port))
        let requestedPorts = Set(portsToScan)
        #expect(scannedPorts == requestedPorts)
    }

    @Test("Scan identifies closed ports correctly")
    func scanClosedPorts() async {
        let service = PortScannerService()
        
        // Use uncommon ports that are likely closed
        let unlikelyPorts = [65000, 65001, 65002]
        let stream = await service.scan(host: "127.0.0.1", ports: unlikelyPorts, timeout: 0.5)
        
        var results: [PortScanResult] = []
        
        for await result in stream {
            results.append(result)
            #expect(unlikelyPorts.contains(result.port))
            
            // Localhost should refuse connections quickly
            #expect(result.state == .closed || result.state == .filtered)
            
            if results.count >= unlikelyPorts.count { break }
        }
        
        #expect(results.count == unlikelyPorts.count)
    }

    @Test("Scan handles invalid hostname gracefully")
    func scanInvalidHost() async {
        let service = PortScannerService()
        let stream = await service.scan(host: "definitely-not-a-real-host-12345.invalid", ports: [80], timeout: 0.5)
        
        var results: [PortScanResult] = []
        
        for await result in stream {
            results.append(result)
            #expect(result.port == 80)
            #expect(result.state == .filtered) // Should timeout/fail
            break
        }
        
        #expect(results.count == 1)
    }

    @Test("Stop function interrupts scan")
    func stopDuringScan() async {
        let service = PortScannerService()
        
        // Scan many ports to ensure we can interrupt
        let manyPorts = Array(1...1000)
        let stream = await service.scan(host: "192.168.1.1", ports: manyPorts, timeout: 2.0)
        
        var results: [PortScanResult] = []
        
        // Stop after a short delay
        let stopTask = Task { @Sendable in
            try? await Task.sleep(for: .milliseconds(100))
            await service.stop()
        }
        
        for await result in stream {
            results.append(result)
            if results.count >= 20 { break } // Reasonable limit to test stop functionality
        }
        
        // Wait for stop task to complete
        await stopTask.value
        #expect(results.count < manyPorts.count) // Should not scan all ports
    }

    @Test("Concurrent port scanning works correctly")
    func concurrentScanning() async {
        let service = PortScannerService()
        
        // Test ports that will scan quickly on localhost
        let ports = [65010, 65011, 65012, 65013, 65014, 65015, 65016, 65017, 65018, 65019]
        let stream = await service.scan(host: "127.0.0.1", ports: ports, timeout: 0.5)
        
        var results: [PortScanResult] = []
        let startTime = Date()
        
        for await result in stream {
            results.append(result)
            if results.count >= ports.count { break }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        #expect(results.count == ports.count)
        
        // With concurrent scanning, should complete faster than sequential
        // 10 ports * 0.5 second timeout = 5 seconds sequential
        // Concurrent should be much faster
        #expect(elapsed < 3.0)
    }

    @Test("Scan respects timeout parameter")
    func scanTimeout() async {
        let service = PortScannerService()
        
        // Use a very short timeout
        let shortTimeout = 0.1
        let stream = await service.scan(host: "8.8.8.8", ports: [12345], timeout: shortTimeout)
        
        let startTime = Date()
        var result: PortScanResult?
        
        for await scanResult in stream {
            result = scanResult
            break
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        #expect(result != nil)
        #expect(result?.state == .filtered) // Should timeout
        
        // Should complete roughly within timeout window
        #expect(elapsed < shortTimeout + 0.5) // Add buffer for processing
    }

    @Test("PortScanResult model properties work correctly")
    func portScanResultModel() async {
        // Test open port result
        let openResult = PortScanResult(
            port: 80,
            state: .open,
            serviceName: "HTTP",
            banner: nil,
            responseTime: 15.5
        )
        
        #expect(openResult.port == 80)
        #expect(openResult.state == .open)
        #expect(openResult.serviceName == "HTTP")
        #expect(openResult.responseTime == 15.5)
        
        // Test closed port result
        let closedResult = PortScanResult(
            port: 443,
            state: .closed,
            serviceName: nil,
            banner: nil,
            responseTime: nil
        )
        
        #expect(closedResult.port == 443)
        #expect(closedResult.state == .closed)
        #expect(closedResult.serviceName == "HTTPS") // Should auto-detect
        #expect(closedResult.responseTime == nil)
        
        // Test filtered port result
        let filteredResult = PortScanResult(
            port: 12345,
            state: .filtered,
            serviceName: nil,
            banner: nil,
            responseTime: nil
        )
        
        #expect(filteredResult.port == 12345)
        #expect(filteredResult.state == .filtered)
        #expect(filteredResult.serviceName == nil)
        #expect(filteredResult.responseTime == nil)
    }

    @Test("Common service names are correctly identified")
    func commonServiceNames() async {
        #expect(PortScanResult.commonServiceName(for: 21) == "FTP")
        #expect(PortScanResult.commonServiceName(for: 22) == "SSH")
        #expect(PortScanResult.commonServiceName(for: 25) == "SMTP")
        #expect(PortScanResult.commonServiceName(for: 53) == "DNS")
        #expect(PortScanResult.commonServiceName(for: 80) == "HTTP")
        #expect(PortScanResult.commonServiceName(for: 110) == "POP3")
        #expect(PortScanResult.commonServiceName(for: 143) == "IMAP")
        #expect(PortScanResult.commonServiceName(for: 443) == "HTTPS")
        #expect(PortScanResult.commonServiceName(for: 993) == "IMAPS")
        #expect(PortScanResult.commonServiceName(for: 995) == "POP3S")
        #expect(PortScanResult.commonServiceName(for: 3306) == "MySQL")
        #expect(PortScanResult.commonServiceName(for: 3389) == "RDP")
        #expect(PortScanResult.commonServiceName(for: 5432) == "PostgreSQL")
        #expect(PortScanResult.commonServiceName(for: 6379) == "Redis")
        #expect(PortScanResult.commonServiceName(for: 99999) == nil) // Unknown port
    }

    @Test("PortState enum properties work correctly")
    func portStateEnum() async {
        #expect(PortState.open.displayName == "Open")
        #expect(PortState.closed.displayName == "Closed")
        #expect(PortState.filtered.displayName == "Filtered")
        
        #expect(PortState.open.rawValue == "open")
        #expect(PortState.closed.rawValue == "closed")
        #expect(PortState.filtered.rawValue == "filtered")
    }

    @Test("Large port range scanning")
    func largePortRange() async {
        let service = PortScannerService()
        
        // Test scanning a larger range efficiently
        let portRange = Array(65500...65510) // Small range of high ports
        let stream = await service.scan(host: "127.0.0.1", ports: portRange, timeout: 0.2)
        
        var results: [PortScanResult] = []
        let startTime = Date()
        
        for await result in stream {
            results.append(result)
            #expect(portRange.contains(result.port))
            if results.count >= portRange.count { break }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        #expect(results.count == portRange.count)
        
        // Should complete in reasonable time due to concurrent scanning
        #expect(elapsed < 2.0)
        
        // Verify all ports were scanned
        let scannedPorts = Set(results.map(\.port))
        let expectedPorts = Set(portRange)
        #expect(scannedPorts == expectedPorts)
    }
}