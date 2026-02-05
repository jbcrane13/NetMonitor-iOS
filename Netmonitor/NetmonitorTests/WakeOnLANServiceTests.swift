import Testing
@testable import Netmonitor

@Suite("WakeOnLAN Tests")
struct WakeOnLANServiceTests {

    @Test("Service initializes with correct state")
    func serviceInitialization() async {
        let service = await WakeOnLANService()
        
        let isSending = await service.isSending
        let lastResult = await service.lastResult
        let lastError = await service.lastError
        
        #expect(isSending == false)
        #expect(lastResult == nil)
        #expect(lastError == nil)
    }

    @Test("Valid MAC address formats accepted")
    func validMACFormats() async {
        let service = await WakeOnLANService()

        // Test colon-separated format
        let colonResult = await service.wake(macAddress: "AA:BB:CC:DD:EE:FF")
        let colonError = await service.lastError
        
        // Should not reject due to format (network send may fail, but format is valid)
        #expect(colonError?.contains("Invalid MAC address format") != true)
        
        // Test dash-separated format
        let dashResult = await service.wake(macAddress: "AA-BB-CC-DD-EE-FF")
        let dashError = await service.lastError
        
        #expect(dashError?.contains("Invalid MAC address format") != true)
        
        // Test lowercase
        let lowercaseResult = await service.wake(macAddress: "aa:bb:cc:dd:ee:ff")
        let lowercaseError = await service.lastError
        
        #expect(lowercaseError?.contains("Invalid MAC address format") != true)
    }

    @Test("Invalid MAC address rejected")
    func invalidMAC() async {
        let service = await WakeOnLANService()
        let result = await service.wake(macAddress: "not-a-mac")
        
        #expect(result == false)
        
        let error = await service.lastError
        #expect(error == "Invalid MAC address format")
        
        let lastResult = await service.lastResult
        #expect(lastResult != nil)
        #expect(lastResult?.success == false)
        #expect(lastResult?.macAddress == "not-a-mac")
    }

    @Test("Short MAC address rejected")
    func shortMAC() async {
        let service = await WakeOnLANService()
        let result = await service.wake(macAddress: "AA:BB:CC")
        
        #expect(result == false)
        
        let error = await service.lastError
        #expect(error == "Invalid MAC address format")
    }

    @Test("Long MAC address rejected")
    func longMAC() async {
        let service = await WakeOnLANService()
        let result = await service.wake(macAddress: "AA:BB:CC:DD:EE:FF:GG:HH")
        
        #expect(result == false)
        
        let error = await service.lastError
        #expect(error == "Invalid MAC address format")
    }

    @Test("MAC with invalid characters rejected")
    func invalidCharactersMAC() async {
        let service = await WakeOnLANService()
        
        let invalidMacs = [
            "GG:HH:II:JJ:KK:LL", // Invalid hex characters
            "AA:BB:CC:DD:EE:ZZ", // Z is not hex
            "AA:BB:CC:DD:EE:",   // Missing last octet
            ":BB:CC:DD:EE:FF",   // Missing first octet
            "AA::CC:DD:EE:FF",   // Double colon
            "AA-BB-CC:DD:EE:FF", // Mixed separators
        ]
        
        for invalidMac in invalidMacs {
            let result = await service.wake(macAddress: invalidMac)
            #expect(result == false)
            
            let error = await service.lastError
            #expect(error == "Invalid MAC address format")
        }
    }

    @Test("Custom broadcast address and port work")
    func customBroadcastAndPort() async {
        let service = await WakeOnLANService()
        
        // Use a local broadcast address and custom port
        let result = await service.wake(
            macAddress: "AA:BB:CC:DD:EE:FF",
            broadcastAddress: "192.168.1.255",
            port: 7
        )
        
        // The result depends on network conditions, but it should not crash
        // and should handle the custom parameters
        let lastResult = await service.lastResult
        #expect(lastResult != nil)
        #expect(lastResult?.macAddress == "AA:BB:CC:DD:EE:FF")
    }

    @Test("Service tracks sending state correctly")
    func sendingStateTracking() async {
        let service = await WakeOnLANService()
        
        // Start a wake operation
        let wakeTask = Task { @Sendable in
            await service.wake(macAddress: "AA:BB:CC:DD:EE:FF")
        }
        
        // Give it a moment to start
        try? await Task.sleep(for: .milliseconds(10))
        
        // Should be sending (might not catch it due to timing, but shouldn't crash)
        let duringSending = await service.isSending
        // Note: This might be false if the operation completed very quickly
        
        // Wait for completion
        let result = await wakeTask.value
        
        // Should no longer be sending
        let afterSending = await service.isSending
        #expect(afterSending == false)
    }

    @Test("Multiple rapid wake attempts handled gracefully")
    func rapidWakeAttempts() async {
        let service = await WakeOnLANService()
        
        let mac = "AA:BB:CC:DD:EE:FF"
        
        // Perform multiple rapid wake attempts
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<3 {
                group.addTask { @Sendable in
                    await service.wake(macAddress: mac)
                }
            }
            
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }
            
            #expect(results.count == 3)
        }
        
        // Service should still be in valid state
        let finalSending = await service.isSending
        let lastResult = await service.lastResult
        
        #expect(finalSending == false)
        #expect(lastResult != nil)
        #expect(lastResult?.macAddress == mac)
    }

    @Test("WakeOnLANResult model properties work correctly")
    func wakeOnLANResultModel() async {
        let successResult = WakeOnLANResult(
            macAddress: "AA:BB:CC:DD:EE:FF",
            success: true,
            error: nil
        )
        
        #expect(successResult.macAddress == "AA:BB:CC:DD:EE:FF")
        #expect(successResult.success == true)
        #expect(successResult.error == nil)
        #expect(successResult.timestamp != nil)
        
        let failureResult = WakeOnLANResult(
            macAddress: "invalid",
            success: false,
            error: "Invalid MAC address"
        )
        
        #expect(failureResult.macAddress == "invalid")
        #expect(failureResult.success == false)
        #expect(failureResult.error == "Invalid MAC address")
    }

    @Test("Default parameters work correctly")
    func defaultParameters() async {
        let service = await WakeOnLANService()
        
        // Test with only MAC address (should use defaults)
        let result = await service.wake(macAddress: "AA:BB:CC:DD:EE:FF")
        
        // Should attempt to send (result depends on network, but shouldn't crash)
        let lastResult = await service.lastResult
        #expect(lastResult != nil)
        #expect(lastResult?.macAddress == "AA:BB:CC:DD:EE:FF")
    }

    @Test("MAC address case normalization")
    func macCaseNormalization() async {
        let service = await WakeOnLANService()
        
        let mixedCaseMacs = [
            "aA:bB:cC:dD:eE:fF",
            "AA:bb:CC:dd:EE:ff",
            "Aa:Bb:Cc:Dd:Ee:Ff"
        ]
        
        for mac in mixedCaseMacs {
            let result = await service.wake(macAddress: mac)
            
            // Should handle case variations gracefully
            let error = await service.lastError
            #expect(error?.contains("Invalid MAC address format") != true)
            
            let lastResult = await service.lastResult
            #expect(lastResult?.macAddress == mac)
        }
    }

    @Test("Edge case broadcast addresses")
    func edgeCaseBroadcastAddresses() async {
        let service = await WakeOnLANService()
        
        let broadcastAddresses = [
            "255.255.255.255", // Global broadcast
            "192.168.1.255",   // Subnet broadcast
            "10.0.0.255",      // Private network broadcast
            "127.0.0.1"        // Localhost (not really broadcast, but valid IP)
        ]
        
        for broadcast in broadcastAddresses {
            let result = await service.wake(
                macAddress: "AA:BB:CC:DD:EE:FF",
                broadcastAddress: broadcast,
                port: 9
            )
            
            // Should handle various broadcast addresses without crashing
            let lastResult = await service.lastResult
            #expect(lastResult != nil)
        }
    }

    @Test("Various port numbers work correctly")
    func variousPortNumbers() async {
        let service = await WakeOnLANService()
        
        let ports: [UInt16] = [7, 9, 40000, 65000]
        
        for port in ports {
            let result = await service.wake(
                macAddress: "AA:BB:CC:DD:EE:FF",
                broadcastAddress: "255.255.255.255",
                port: port
            )
            
            // Should handle different port numbers
            let lastResult = await service.lastResult
            #expect(lastResult != nil)
            #expect(lastResult?.macAddress == "AA:BB:CC:DD:EE:FF")
        }
    }
}
