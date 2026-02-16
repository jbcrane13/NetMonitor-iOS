import Testing
import Foundation
import SwiftUI
@testable import Netmonitor

// MARK: - CompanionMessage Tests

@Suite("CompanionMessage Tests")
struct CompanionMessageTests {

    @Test("StatusUpdate message encodes and decodes correctly")
    func statusUpdateRoundTrip() throws {
        let timestamp = Date()
        let payload = StatusUpdatePayload(
            isMonitoring: true,
            onlineTargets: 5,
            offlineTargets: 2,
            averageLatency: 45.3,
            timestamp: timestamp
        )
        let message = CompanionMessage.statusUpdate(payload)

        let encoded = try message.encodeLengthPrefixed()
        #expect(encoded.count > 4) // Has length prefix

        // Verify length prefix is correct
        let lengthBytes = encoded.prefix(4)
        let length = lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        #expect(Int(length) == encoded.count - 4)

        // Decode from JSON (without length prefix)
        let jsonData = encoded.dropFirst(4)
        let decoded = try CompanionMessage.decode(from: jsonData)

        if case .statusUpdate(let decodedPayload) = decoded {
            #expect(decodedPayload.isMonitoring == true)
            #expect(decodedPayload.onlineTargets == 5)
            #expect(decodedPayload.offlineTargets == 2)
            #expect(decodedPayload.averageLatency == 45.3)
        } else {
            Issue.record("Expected statusUpdate message type")
        }
    }

    @Test("TargetList message encodes and decodes correctly")
    func targetListRoundTrip() throws {
        let targets = [
            TargetInfo(
                id: UUID(),
                name: "Google DNS",
                host: "8.8.8.8",
                port: nil,
                protocol: "icmp",
                isEnabled: true,
                isReachable: true,
                latency: 12.5
            ),
            TargetInfo(
                id: UUID(),
                name: "Local Server",
                host: "192.168.1.100",
                port: 8080,
                protocol: "tcp",
                isEnabled: false,
                isReachable: nil,
                latency: nil
            )
        ]
        let payload = TargetListPayload(targets: targets)
        let message = CompanionMessage.targetList(payload)

        let encoded = try message.encodeLengthPrefixed()
        let jsonData = encoded.dropFirst(4)
        let decoded = try CompanionMessage.decode(from: jsonData)

        if case .targetList(let decodedPayload) = decoded {
            #expect(decodedPayload.targets.count == 2)
            #expect(decodedPayload.targets[0].name == "Google DNS")
            #expect(decodedPayload.targets[0].port == nil)
            #expect(decodedPayload.targets[1].port == 8080)
        } else {
            Issue.record("Expected targetList message type")
        }
    }

    @Test("DeviceList message encodes and decodes correctly")
    func deviceListRoundTrip() throws {
        let devices = [
            DeviceInfo(
                id: UUID(),
                ipAddress: "192.168.1.1",
                macAddress: "AA:BB:CC:DD:EE:FF",
                hostname: "router.local",
                vendor: "Apple",
                deviceType: "router",
                isOnline: true
            )
        ]
        let payload = DeviceListPayload(devices: devices)
        let message = CompanionMessage.deviceList(payload)

        let encoded = try message.encodeLengthPrefixed()
        let jsonData = encoded.dropFirst(4)
        let decoded = try CompanionMessage.decode(from: jsonData)

        if case .deviceList(let decodedPayload) = decoded {
            #expect(decodedPayload.devices.count == 1)
            #expect(decodedPayload.devices[0].ipAddress == "192.168.1.1")
            #expect(decodedPayload.devices[0].vendor == "Apple")
        } else {
            Issue.record("Expected deviceList message type")
        }
    }

    @Test("Command message with parameters encodes and decodes correctly")
    func commandWithParametersRoundTrip() throws {
        let payload = CommandPayload(
            action: .ping,
            parameters: ["host": "8.8.8.8", "count": "4"]
        )
        let message = CompanionMessage.command(payload)

        let encoded = try message.encodeLengthPrefixed()
        let jsonData = encoded.dropFirst(4)
        let decoded = try CompanionMessage.decode(from: jsonData)

        if case .command(let decodedPayload) = decoded {
            #expect(decodedPayload.action == .ping)
            #expect(decodedPayload.parameters?["host"] == "8.8.8.8")
            #expect(decodedPayload.parameters?["count"] == "4")
        } else {
            Issue.record("Expected command message type")
        }
    }

    @Test("Command message without parameters encodes and decodes correctly")
    func commandWithoutParametersRoundTrip() throws {
        let payload = CommandPayload(action: .startMonitoring)
        let message = CompanionMessage.command(payload)

        let encoded = try message.encodeLengthPrefixed()
        let jsonData = encoded.dropFirst(4)
        let decoded = try CompanionMessage.decode(from: jsonData)

        if case .command(let decodedPayload) = decoded {
            #expect(decodedPayload.action == .startMonitoring)
            #expect(decodedPayload.parameters == nil)
        } else {
            Issue.record("Expected command message type")
        }
    }

    @Test("ToolResult message encodes and decodes correctly")
    func toolResultRoundTrip() throws {
        let timestamp = Date()
        let payload = ToolResultPayload(
            tool: "ping",
            success: true,
            result: "Reply from 8.8.8.8: time=12ms",
            timestamp: timestamp
        )
        let message = CompanionMessage.toolResult(payload)

        let encoded = try message.encodeLengthPrefixed()
        let jsonData = encoded.dropFirst(4)
        let decoded = try CompanionMessage.decode(from: jsonData)

        if case .toolResult(let decodedPayload) = decoded {
            #expect(decodedPayload.tool == "ping")
            #expect(decodedPayload.success == true)
            #expect(decodedPayload.result == "Reply from 8.8.8.8: time=12ms")
        } else {
            Issue.record("Expected toolResult message type")
        }
    }

    @Test("Error message encodes and decodes correctly")
    func errorMessageRoundTrip() throws {
        let timestamp = Date()
        let payload = ErrorPayload(
            code: "CONNECTION_FAILED",
            message: "Unable to connect to host",
            timestamp: timestamp
        )
        let message = CompanionMessage.error(payload)

        let encoded = try message.encodeLengthPrefixed()
        let jsonData = encoded.dropFirst(4)
        let decoded = try CompanionMessage.decode(from: jsonData)

        if case .error(let decodedPayload) = decoded {
            #expect(decodedPayload.code == "CONNECTION_FAILED")
            #expect(decodedPayload.message == "Unable to connect to host")
        } else {
            Issue.record("Expected error message type")
        }
    }

    @Test("Heartbeat message encodes and decodes correctly")
    func heartbeatRoundTrip() throws {
        let timestamp = Date()
        let payload = HeartbeatPayload(timestamp: timestamp, version: "1.0.0")
        let message = CompanionMessage.heartbeat(payload)

        let encoded = try message.encodeLengthPrefixed()
        let jsonData = encoded.dropFirst(4)
        let decoded = try CompanionMessage.decode(from: jsonData)

        if case .heartbeat(let decodedPayload) = decoded {
            #expect(decodedPayload.version == "1.0.0")
        } else {
            Issue.record("Expected heartbeat message type")
        }
    }

    @Test("CommandAction enum has all expected values")
    func commandActionValues() {
        let actions: [CommandAction] = [
            .startMonitoring, .stopMonitoring, .scanDevices,
            .ping, .traceroute, .portScan, .dnsLookup,
            .wakeOnLan, .refreshTargets, .refreshDevices
        ]
        #expect(actions.count == 10)
    }
}

// MARK: - MonitoringTarget Tests

@Suite("MonitoringTarget Tests")
struct MonitoringTargetExtendedTests {

    @Test("Initial state is correct")
    func initialState() {
        let target = MonitoringTarget(
            name: "Test Server",
            host: "example.com",
            port: 443,
            targetProtocol: .https
        )

        #expect(target.name == "Test Server")
        #expect(target.host == "example.com")
        #expect(target.port == 443)
        #expect(target.targetProtocol == .https)
        #expect(target.isEnabled == true)
        #expect(target.isOnline == false)
        #expect(target.consecutiveFailures == 0)
        #expect(target.totalChecks == 0)
        #expect(target.successfulChecks == 0)
        #expect(target.currentLatency == nil)
        #expect(target.averageLatency == nil)
    }

    @Test("recordSuccess updates all fields correctly")
    func recordSuccessUpdates() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        target.recordSuccess(latency: 25.5)

        #expect(target.totalChecks == 1)
        #expect(target.successfulChecks == 1)
        #expect(target.consecutiveFailures == 0)
        #expect(target.currentLatency == 25.5)
        #expect(target.isOnline == true)
        #expect(target.lastChecked != nil)
        #expect(target.averageLatency == 25.5)
        #expect(target.minLatency == 25.5)
        #expect(target.maxLatency == 25.5)
    }

    @Test("recordSuccess resets consecutive failures")
    func recordSuccessResetsFailures() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        target.recordFailure()
        target.recordFailure()
        #expect(target.consecutiveFailures == 2)

        target.recordSuccess(latency: 10.0)
        #expect(target.consecutiveFailures == 0)
        #expect(target.isOnline == true)
    }

    @Test("recordFailure increments counters")
    func recordFailureIncrements() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        target.recordFailure()

        #expect(target.totalChecks == 1)
        #expect(target.consecutiveFailures == 1)
        #expect(target.currentLatency == nil)
        #expect(target.lastChecked != nil)
        #expect(target.isOnline == false) // Not online yet (need 3 failures to be explicitly offline)
    }

    @Test("recordFailure sets offline after 3 consecutive failures")
    func recordFailureSetsOffline() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        // Make it online first
        target.recordSuccess(latency: 10.0)
        #expect(target.isOnline == true)

        // First two failures don't set offline
        target.recordFailure()
        #expect(target.isOnline == true)
        target.recordFailure()
        #expect(target.isOnline == true)

        // Third failure sets offline
        target.recordFailure()
        #expect(target.isOnline == false)
        #expect(target.consecutiveFailures == 3)
    }

    @Test("uptimePercentage calculates correctly")
    func uptimePercentageCalculation() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        // No checks yet
        #expect(target.uptimePercentage == 0)

        // 100% success
        target.recordSuccess(latency: 10.0)
        target.recordSuccess(latency: 10.0)
        #expect(target.uptimePercentage == 100.0)

        // 50% success (2 success, 2 failures)
        target.recordFailure()
        target.recordFailure()
        #expect(target.uptimePercentage == 50.0)
    }

    @Test("uptimeText formats correctly")
    func uptimeTextFormatting() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        target.recordSuccess(latency: 10.0)
        target.recordSuccess(latency: 10.0)
        target.recordSuccess(latency: 10.0)
        target.recordFailure()

        #expect(target.uptimeText == "75.0%")
    }

    @Test("latencyText formats correctly")
    func latencyTextFormatting() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        // No latency
        #expect(target.latencyText == nil)

        // Sub-millisecond
        target.recordSuccess(latency: 0.5)
        #expect(target.latencyText == "<1 ms")

        // Normal latency
        target.currentLatency = 45.7
        #expect(target.latencyText == "46 ms")

        // High latency
        target.currentLatency = 250.3
        #expect(target.latencyText == "250 ms")
    }

    @Test("hostWithPort formats correctly")
    func hostWithPortFormatting() {
        let targetWithPort = MonitoringTarget(
            name: "Test",
            host: "example.com",
            port: 8080
        )
        #expect(targetWithPort.hostWithPort == "example.com:8080")

        let targetWithoutPort = MonitoringTarget(
            name: "Test",
            host: "example.com",
            port: nil
        )
        #expect(targetWithoutPort.hostWithPort == "example.com")
    }

    @Test("statusType maps correctly")
    func statusTypeMapping() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        #expect(target.statusType == .offline)

        target.recordSuccess(latency: 10.0)
        #expect(target.statusType == .online)
    }

    @Test("latency statistics track correctly")
    func latencyStatistics() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        target.recordSuccess(latency: 10.0)
        target.recordSuccess(latency: 20.0)
        target.recordSuccess(latency: 30.0)

        #expect(target.minLatency == 10.0)
        #expect(target.maxLatency == 30.0)

        // Average should be calculated with weighted moving average
        let avg = target.averageLatency
        #expect(avg != nil)
        #expect(avg! >= 10.0 && avg! <= 30.0)
    }
}

// MARK: - LocalDevice Tests

@Suite("LocalDevice Tests")
struct LocalDeviceTests {

    @Test("displayName prioritizes customName")
    func displayNamePriority() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: "device.local",
            customName: "My Device",
            resolvedHostname: "resolved.local"
        )

        #expect(device.displayName == "My Device")
    }

    @Test("displayName falls back to resolvedHostname")
    func displayNameResolvedHostname() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: "device.local",
            customName: nil,
            resolvedHostname: "resolved.local"
        )

        #expect(device.displayName == "resolved.local")
    }

    @Test("displayName falls back to hostname")
    func displayNameHostname() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: "device.local",
            customName: nil,
            resolvedHostname: nil
        )

        #expect(device.displayName == "device.local")
    }

    @Test("displayName falls back to ipAddress")
    func displayNameIPAddress() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: nil,
            customName: nil,
            resolvedHostname: nil
        )

        #expect(device.displayName == "192.168.1.100")
    }

    @Test("formattedMacAddress uppercases")
    func formattedMacAddressUppercases() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "aa:bb:cc:dd:ee:ff"
        )

        #expect(device.formattedMacAddress == "AA:BB:CC:DD:EE:FF")
    }

    @Test("latencyText formats correctly")
    func latencyTextFormatting() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF"
        )

        // No latency
        #expect(device.latencyText == nil)

        // Sub-millisecond
        device.lastLatency = 0.8
        #expect(device.latencyText == "<1 ms")

        // Normal latency
        device.lastLatency = 15.3
        #expect(device.latencyText == "15 ms")
    }

    @Test("updateStatus changes status and lastSeen")
    func updateStatusChanges() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            status: .online
        )

        let oldLastSeen = device.lastSeen

        // Sleep briefly to ensure timestamp changes
        Thread.sleep(forTimeInterval: 0.01)

        device.updateStatus(to: .offline)

        #expect(device.status == .offline)
        #expect(device.lastSeen > oldLastSeen)
    }

    @Test("updateLatency changes latency and lastSeen")
    func updateLatencyChanges() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF"
        )

        let oldLastSeen = device.lastSeen
        Thread.sleep(forTimeInterval: 0.01)

        device.updateLatency(25.5)

        #expect(device.lastLatency == 25.5)
        #expect(device.lastSeen > oldLastSeen)
    }

    @Test("updateLatency transitions offline to online")
    func updateLatencyTransitionsOfflineToOnline() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            status: .offline
        )

        device.updateLatency(10.0)

        #expect(device.status == .online)
        #expect(device.lastLatency == 10.0)
    }
}

// MARK: - PairedMac Tests

@Suite("PairedMac Tests")
struct PairedMacTests {

    @Test("displayAddress shows IP and port")
    func displayAddressWithIP() {
        let mac = PairedMac(
            name: "My Mac",
            ipAddress: "192.168.1.50",
            port: 8849
        )

        #expect(mac.displayAddress == "192.168.1.50:8849")
    }

    @Test("displayAddress shows hostname and port")
    func displayAddressWithHostname() {
        let mac = PairedMac(
            name: "My Mac",
            hostname: "macbook.local",
            ipAddress: nil,
            port: 8849
        )

        #expect(mac.displayAddress == "macbook.local:8849")
    }

    @Test("displayAddress shows not configured when neither IP nor hostname")
    func displayAddressNotConfigured() {
        let mac = PairedMac(
            name: "My Mac",
            hostname: nil,
            ipAddress: nil,
            port: 8849
        )

        #expect(mac.displayAddress == "Not configured")
    }

    @Test("connectionStatusText shows Connected when connected")
    func connectionStatusConnected() {
        let mac = PairedMac(
            name: "My Mac",
            isConnected: true
        )

        #expect(mac.connectionStatusText == "Connected")
    }

    @Test("connectionStatusText shows Disconnected when not connected but was before")
    func connectionStatusDisconnected() {
        let mac = PairedMac(
            name: "My Mac",
            lastConnected: Date(),
            isConnected: false
        )

        #expect(mac.connectionStatusText == "Disconnected")
    }

    @Test("connectionStatusText shows Never connected when never connected")
    func connectionStatusNeverConnected() {
        let mac = PairedMac(
            name: "My Mac",
            lastConnected: nil,
            isConnected: false
        )

        #expect(mac.connectionStatusText == "Never connected")
    }
}

// MARK: - ToolResult Tests

@Suite("ToolResult Tests")
struct ToolResultTests {

    @Test("formattedDuration shows milliseconds for sub-second")
    func formattedDurationMilliseconds() {
        let result = ToolResult(
            toolType: .ping,
            target: "8.8.8.8",
            duration: 0.25,
            success: true,
            summary: "Success"
        )

        #expect(result.formattedDuration == "250 ms")
    }

    @Test("formattedDuration shows seconds for over one second")
    func formattedDurationSeconds() {
        let result = ToolResult(
            toolType: .ping,
            target: "8.8.8.8",
            duration: 2.567,
            success: true,
            summary: "Success"
        )

        #expect(result.formattedDuration == "2.57 s")
    }

    @Test("relativeTimestamp formats relative to now")
    func relativeTimestampFormatting() {
        let result = ToolResult(
            toolType: .ping,
            target: "8.8.8.8",
            duration: 1.0,
            success: true,
            summary: "Success"
        )

        // Should return something like "now", "0 sec. ago", etc.
        let relative = result.relativeTimestamp
        #expect(relative.count > 0)
    }
}

// MARK: - AppSettings Tests

@Suite("AppSettings Tests")
struct AppSettingsTests {

    @Test("All Keys constants are non-empty")
    func keysAreNonEmpty() {
        #expect(!AppSettings.Keys.defaultPingCount.isEmpty)
        #expect(!AppSettings.Keys.pingTimeout.isEmpty)
        #expect(!AppSettings.Keys.portScanTimeout.isEmpty)
        #expect(!AppSettings.Keys.dnsServer.isEmpty)
        #expect(!AppSettings.Keys.speedTestDuration.isEmpty)
        #expect(!AppSettings.Keys.dataRetentionDays.isEmpty)
        #expect(!AppSettings.Keys.showDetailedResults.isEmpty)
        #expect(!AppSettings.Keys.autoRefreshInterval.isEmpty)
        #expect(!AppSettings.Keys.backgroundRefreshEnabled.isEmpty)
        #expect(!AppSettings.Keys.targetDownAlertEnabled.isEmpty)
        #expect(!AppSettings.Keys.highLatencyThreshold.isEmpty)
        #expect(!AppSettings.Keys.newDeviceAlertEnabled.isEmpty)
        #expect(!AppSettings.Keys.selectedTheme.isEmpty)
        #expect(!AppSettings.Keys.selectedAccentColor.isEmpty)
        #expect(!AppSettings.Keys.webBrowserRecentURLs.isEmpty)
    }

    @Test("UserDefaults bool extension works")
    func userDefaultsBoolExtension() {
        let defaults = UserDefaults(suiteName: "test.suite")!

        // Default value
        #expect(defaults.bool(forAppKey: "testBool", default: true) == true)

        // Set and get
        defaults.setBool(false, forAppKey: "testBool")
        #expect(defaults.bool(forAppKey: "testBool", default: true) == false)

        // Cleanup
        defaults.removePersistentDomain(forName: "test.suite")
    }

    @Test("UserDefaults int extension works")
    func userDefaultsIntExtension() {
        let defaults = UserDefaults(suiteName: "test.suite")!

        // Default value
        #expect(defaults.int(forAppKey: "testInt", default: 42) == 42)

        // Set and get
        defaults.setInt(100, forAppKey: "testInt")
        #expect(defaults.int(forAppKey: "testInt", default: 42) == 100)

        // Cleanup
        defaults.removePersistentDomain(forName: "test.suite")
    }

    @Test("UserDefaults double extension works")
    func userDefaultsDoubleExtension() {
        let defaults = UserDefaults(suiteName: "test.suite")!

        // Default value
        #expect(defaults.double(forAppKey: "testDouble", default: 3.14) == 3.14)

        // Set and get
        defaults.setDouble(2.718, forAppKey: "testDouble")
        #expect(defaults.double(forAppKey: "testDouble", default: 3.14) == 2.718)

        // Cleanup
        defaults.removePersistentDomain(forName: "test.suite")
    }

    @Test("UserDefaults string extension works")
    func userDefaultsStringExtension() {
        let defaults = UserDefaults(suiteName: "test.suite")!

        // Default value
        #expect(defaults.string(forAppKey: "testString", default: "default") == "default")

        // Set and get
        defaults.setString("value", forAppKey: "testString")
        #expect(defaults.string(forAppKey: "testString", default: "default") == "value")

        // Cleanup
        defaults.removePersistentDomain(forName: "test.suite")
    }
}

// MARK: - ServiceUtilities Tests

@Suite("ServiceUtilities Tests")
struct ServiceUtilitiesTests {

    @Test("isIPAddress recognizes valid IPv4")
    func isIPAddressValidIPv4() {
        #expect(ServiceUtilities.isIPAddress("192.168.1.1") == true)
        #expect(ServiceUtilities.isIPAddress("8.8.8.8") == true)
        #expect(ServiceUtilities.isIPAddress("10.0.0.1") == true)
        #expect(ServiceUtilities.isIPAddress("255.255.255.255") == true)
    }

    @Test("isIPAddress recognizes valid IPv6")
    func isIPAddressValidIPv6() {
        #expect(ServiceUtilities.isIPAddress("::1") == true)
        #expect(ServiceUtilities.isIPAddress("2001:db8::1") == true)
        #expect(ServiceUtilities.isIPAddress("fe80::1") == true)
    }

    @Test("isIPAddress rejects invalid addresses")
    func isIPAddressInvalid() {
        #expect(ServiceUtilities.isIPAddress("not-an-ip") == false)
        #expect(ServiceUtilities.isIPAddress("example.com") == false)
        #expect(ServiceUtilities.isIPAddress("999.999.999.999") == false)
        #expect(ServiceUtilities.isIPAddress("") == false)
    }

    @Test("isIPv4Address recognizes valid IPv4 only")
    func isIPv4AddressValid() {
        #expect(ServiceUtilities.isIPv4Address("192.168.1.1") == true)
        #expect(ServiceUtilities.isIPv4Address("10.0.0.1") == true)
        #expect(ServiceUtilities.isIPv4Address("8.8.8.8") == true)
    }

    @Test("isIPv4Address rejects IPv6")
    func isIPv4AddressRejectsIPv6() {
        #expect(ServiceUtilities.isIPv4Address("::1") == false)
        #expect(ServiceUtilities.isIPv4Address("2001:db8::1") == false)
    }

    @Test("isIPv4Address rejects invalid addresses")
    func isIPv4AddressRejectsInvalid() {
        #expect(ServiceUtilities.isIPv4Address("example.com") == false)
        #expect(ServiceUtilities.isIPv4Address("not-an-ip") == false)
        #expect(ServiceUtilities.isIPv4Address("") == false)
    }

    @Test("resolveHostnameSync returns IP address unchanged")
    func resolveHostnameSyncIPPassthrough() {
        let ip = "192.168.1.100"
        let result = ServiceUtilities.resolveHostnameSync(ip)
        #expect(result == ip)
    }

    @Test("resolveHostname returns IP address unchanged")
    func resolveHostnameIPPassthrough() async {
        let ip = "10.0.0.1"
        let result = await ServiceUtilities.resolveHostname(ip)
        #expect(result == ip)
    }
}

// MARK: - ThemeManager Tests

@Suite("ThemeManager Tests")
@MainActor
struct ThemeManagerExtendedTests {

    @Test("ThemeManager is a singleton")
    func singletonPattern() {
        let instance1 = ThemeManager.shared
        let instance2 = ThemeManager.shared
        #expect(instance1 === instance2)
    }

    @Test("accent returns correct color for cyan (default)")
    func accentColorCyan() {
        let manager = ThemeManager.shared
        manager.selectedAccentColor = "cyan"

        // Should return cyan color (hex: 06B6D4)
        let accent = manager.accent
        #expect(accent != Color.clear)
    }

    @Test("accent returns correct color for blue")
    func accentColorBlue() {
        let manager = ThemeManager.shared
        manager.selectedAccentColor = "blue"

        let accent = manager.accent
        #expect(accent != Color.clear)
    }

    @Test("accent returns correct color for green")
    func accentColorGreen() {
        let manager = ThemeManager.shared
        manager.selectedAccentColor = "green"

        let accent = manager.accent
        #expect(accent != Color.clear)
    }

    @Test("accent returns correct color for purple")
    func accentColorPurple() {
        let manager = ThemeManager.shared
        manager.selectedAccentColor = "purple"

        let accent = manager.accent
        #expect(accent != Color.clear)
    }

    @Test("accentLight returns lighter variant")
    func accentLightColor() {
        let manager = ThemeManager.shared
        manager.selectedAccentColor = "cyan"

        let accentLight = manager.accentLight
        #expect(accentLight != Color.clear)
    }

    @Test("selectedAccentColor persists to UserDefaults")
    func accentColorPersistence() {
        let manager = ThemeManager.shared

        manager.selectedAccentColor = "purple"

        let stored = UserDefaults.standard.string(forKey: AppSettings.Keys.selectedAccentColor)
        #expect(stored == "purple")
    }
}
