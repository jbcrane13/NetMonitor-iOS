import Testing
import Foundation
import SwiftData
@testable import Netmonitor

// MARK: - BonjourDiscoveryService Tests

@Suite("BonjourDiscoveryService Tests")
@MainActor
struct BonjourDiscoveryServiceTests {

    @Test("Initial state is correct")
    func initialState() {
        let service = BonjourDiscoveryService()
        #expect(service.discoveredServices.isEmpty)
        #expect(service.isDiscovering == false)
    }

    @Test("State changes when discovery starts")
    func discoveryStateChange() async {
        let service = BonjourDiscoveryService()

        service.startDiscovery(serviceType: "_http._tcp")
        #expect(service.isDiscovering == true)
        #expect(service.discoveredServices.isEmpty)

        service.stopDiscovery()
        #expect(service.isDiscovering == false)
    }

    @Test("Stop discovery clears state")
    func stopDiscoveryClearsState() {
        let service = BonjourDiscoveryService()

        service.startDiscovery(serviceType: "_ssh._tcp")
        #expect(service.isDiscovering == true)

        service.stopDiscovery()
        #expect(service.isDiscovering == false)
    }
}

// MARK: - BonjourService Model Tests

@Suite("BonjourService Model Tests")
struct BonjourServiceModelTests {

    @Test("Full type combines type and domain")
    func fullType() {
        let service = BonjourService(name: "Test", type: "_http._tcp", domain: "local.")
        #expect(service.fullType == "_http._tcp.local.")
    }

    @Test("Service category classification - Web")
    func categoryWeb() {
        let http = BonjourService(name: "Test", type: "_http._tcp")
        #expect(http.serviceCategory == "Web")

        let https = BonjourService(name: "Test", type: "_https._tcp")
        #expect(https.serviceCategory == "Web")
    }

    @Test("Service category classification - Remote Access")
    func categoryRemoteAccess() {
        let ssh = BonjourService(name: "Test", type: "_ssh._tcp")
        #expect(ssh.serviceCategory == "Remote Access")

        let sftp = BonjourService(name: "Test", type: "_sftp._tcp")
        #expect(sftp.serviceCategory == "Remote Access")
    }

    @Test("Service category classification - File Sharing")
    func categoryFileSharing() {
        let smb = BonjourService(name: "Test", type: "_smb._tcp")
        #expect(smb.serviceCategory == "File Sharing")

        let afp = BonjourService(name: "Test", type: "_afpovertcp._tcp")
        #expect(afp.serviceCategory == "File Sharing")
    }

    @Test("Service category classification - Printing")
    func categoryPrinting() {
        let printer = BonjourService(name: "Test", type: "_printer._tcp")
        #expect(printer.serviceCategory == "Printing")

        let ipp = BonjourService(name: "Test", type: "_ipp._tcp")
        #expect(ipp.serviceCategory == "Printing")
    }

    @Test("Service category classification - AirPlay")
    func categoryAirPlay() {
        let airplay = BonjourService(name: "Test", type: "_airplay._tcp")
        #expect(airplay.serviceCategory == "AirPlay")

        let raop = BonjourService(name: "Test", type: "_raop._tcp")
        #expect(raop.serviceCategory == "AirPlay")
    }

    @Test("Service category classification - Other services")
    func categoryOther() {
        let chromecast = BonjourService(name: "Test", type: "_googlecast._tcp")
        #expect(chromecast.serviceCategory == "Chromecast")

        let spotify = BonjourService(name: "Test", type: "_spotify-connect._tcp")
        #expect(spotify.serviceCategory == "Spotify")

        let homekit = BonjourService(name: "Test", type: "_homekit._tcp")
        #expect(homekit.serviceCategory == "HomeKit")
    }

    @Test("Service category classification - Unknown")
    func categoryUnknown() {
        let unknown = BonjourService(name: "Test", type: "_custom._tcp")
        #expect(unknown.serviceCategory == "Other")
    }

    @Test("BonjourService has unique IDs")
    func uniqueIDs() {
        let a = BonjourService(name: "Test", type: "_http._tcp")
        let b = BonjourService(name: "Test", type: "_http._tcp")
        #expect(a.id != b.id)
    }

    @Test("BonjourService with optional fields")
    func optionalFields() {
        let service = BonjourService(
            name: "My Service",
            type: "_http._tcp",
            domain: "local.",
            hostName: "myhost.local",
            port: 8080,
            txtRecords: ["path": "/api"],
            addresses: ["192.168.1.100"]
        )
        #expect(service.hostName == "myhost.local")
        #expect(service.port == 8080)
        #expect(service.txtRecords["path"] == "/api")
        #expect(service.addresses.count == 1)
    }
}

// MARK: - DataMaintenanceService Tests

@Suite("DataMaintenanceService Tests")
@MainActor
struct DataMaintenanceServiceTests {

    @Test("Prune data skips when retention days is 0")
    func skipWhenRetentionZero() {
        // Set retention to 0
        UserDefaults.standard.set(0, forKey: "dataRetentionDays")

        // Create in-memory container
        let schema = Schema([ToolResult.self, SpeedTestResult.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        // Add old record
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let toolResult = ToolResult(
            toolType: .ping,
            target: "test.com",
            success: true,
            summary: "success"
        )
        toolResult.timestamp = oldDate
        context.insert(toolResult)
        try! context.save()

        // Run prune
        DataMaintenanceService.pruneExpiredData(modelContext: context)

        // Verify record still exists (not deleted)
        let descriptor = FetchDescriptor<ToolResult>()
        let results = try! context.fetch(descriptor)
        #expect(results.count == 1)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "dataRetentionDays")
    }

    @Test("Prune data deletes old records")
    func pruneOldRecords() {
        // Set retention to 30 days
        UserDefaults.standard.set(30, forKey: "dataRetentionDays")

        // Create in-memory container
        let schema = Schema([ToolResult.self, SpeedTestResult.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        // Add old record (60 days ago)
        let oldDate = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let oldToolResult = ToolResult(
            toolType: .ping,
            target: "old.com",
            success: true,
            summary: "success"
        )
        oldToolResult.timestamp = oldDate
        context.insert(oldToolResult)

        // Add recent record (10 days ago)
        let recentDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let recentToolResult = ToolResult(
            toolType: .ping,
            target: "recent.com",
            success: true,
            summary: "success"
        )
        recentToolResult.timestamp = recentDate
        context.insert(recentToolResult)

        try! context.save()

        // Run prune
        DataMaintenanceService.pruneExpiredData(modelContext: context)

        // Verify only recent record remains
        let descriptor = FetchDescriptor<ToolResult>()
        let results = try! context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.target == "recent.com")

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "dataRetentionDays")
    }

    @Test("Prune data preserves recent records")
    func preserveRecentRecords() {
        // Set retention to 30 days
        UserDefaults.standard.set(30, forKey: "dataRetentionDays")

        // Create in-memory container
        let schema = Schema([ToolResult.self, SpeedTestResult.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        // Add recent record
        let recentDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let toolResult = ToolResult(
            toolType: .traceroute,
            target: "test.com",
            success: true,
            summary: "success"
        )
        toolResult.timestamp = recentDate
        context.insert(toolResult)
        try! context.save()

        // Run prune
        DataMaintenanceService.pruneExpiredData(modelContext: context)

        // Verify record still exists
        let descriptor = FetchDescriptor<ToolResult>()
        let results = try! context.fetch(descriptor)
        #expect(results.count == 1)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "dataRetentionDays")
    }

    @Test("Prune data uses default retention when not set")
    func defaultRetention() {
        // Remove any existing setting to test default
        UserDefaults.standard.removeObject(forKey: "dataRetentionDays")

        // Create in-memory container
        let schema = Schema([ToolResult.self, SpeedTestResult.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        // Add record older than 30 days (default)
        let oldDate = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        let toolResult = ToolResult(
            toolType: .ping,
            target: "test.com",
            success: true,
            summary: "success"
        )
        toolResult.timestamp = oldDate
        context.insert(toolResult)
        try! context.save()

        // Run prune (should use default 30 days)
        DataMaintenanceService.pruneExpiredData(modelContext: context)

        // Verify old record was deleted
        let descriptor = FetchDescriptor<ToolResult>()
        let results = try! context.fetch(descriptor)
        #expect(results.isEmpty)
    }
}

// MARK: - DeviceDiscoveryService Tests

@Suite("DeviceDiscoveryService Tests")
@MainActor
struct DeviceDiscoveryServiceTests {

    @Test("Initial state is correct")
    func initialState() {
        let service = DeviceDiscoveryService()
        #expect(service.discoveredDevices.isEmpty)
        #expect(service.isScanning == false)
        #expect(service.scanProgress == 0)
        #expect(service.scanPhase == .idle)
        #expect(service.lastScanDate == nil)
    }

    @Test("Stop scan changes state")
    func stopScan() {
        let service = DeviceDiscoveryService()
        service.stopScan()
        #expect(service.isScanning == false)
    }
}

// MARK: - ScanDisplayPhase Tests

@Suite("ScanDisplayPhase Tests")
struct ScanDisplayPhaseTests {

    @Test("Scan phase raw values match display text")
    func rawValues() {
        #expect(ScanDisplayPhase.idle.rawValue == "")
        #expect(ScanDisplayPhase.arpScan.rawValue == "Scanning network…")
        #expect(ScanDisplayPhase.tcpProbe.rawValue == "Probing ports…")
        #expect(ScanDisplayPhase.bonjour.rawValue == "Bonjour discovery…")
        #expect(ScanDisplayPhase.ssdp.rawValue == "UPnP discovery…")
        #expect(ScanDisplayPhase.icmpLatency.rawValue == "Measuring latency…")
        #expect(ScanDisplayPhase.companion.rawValue == "Mac companion…")
        #expect(ScanDisplayPhase.resolving.rawValue == "Resolving names…")
        #expect(ScanDisplayPhase.done.rawValue == "Complete")
    }

    @Test("All scan phases are defined")
    func allPhasesDefined() {
        let phases: [ScanDisplayPhase] = [
            .idle, .arpScan, .tcpProbe, .bonjour,
            .ssdp, .icmpLatency, .companion, .resolving, .done
        ]
        #expect(phases.count == 9)
    }
}

// MARK: - MacConnectionService Tests

@Suite("MacConnectionService Tests")
@MainActor
struct MacConnectionServiceTests {

    @Test("Initial state is correct")
    func initialState() {
        let service = MacConnectionService()
        #expect(service.connectionState == .disconnected)
        #expect(service.discoveredMacs.isEmpty)
        #expect(service.isBrowsing == false)
        #expect(service.connectedMacName == nil)
        #expect(service.lastStatusUpdate == nil)
        #expect(service.lastTargetList == nil)
        #expect(service.lastDeviceList == nil)
    }

    @Test("Start browsing changes state")
    func startBrowsing() {
        let service = MacConnectionService()
        service.startBrowsing()
        #expect(service.isBrowsing == true)
        #expect(service.discoveredMacs.isEmpty)

        service.stopBrowsing()
    }

    @Test("Stop browsing changes state")
    func stopBrowsing() {
        let service = MacConnectionService()
        service.startBrowsing()
        #expect(service.isBrowsing == true)

        service.stopBrowsing()
        #expect(service.isBrowsing == false)
    }

    @Test("Disconnect clears state")
    func disconnect() {
        let service = MacConnectionService()
        service.disconnect()
        #expect(service.connectionState == .disconnected)
        #expect(service.connectedMacName == nil)
        #expect(service.lastStatusUpdate == nil)
        #expect(service.lastTargetList == nil)
        #expect(service.lastDeviceList == nil)
    }
}

// MARK: - MacConnectionState Tests

@Suite("MacConnectionState Tests")
struct MacConnectionStateTests {

    @Test("Connection state isConnected property")
    func isConnected() {
        #expect(MacConnectionState.disconnected.isConnected == false)
        #expect(MacConnectionState.connecting.isConnected == false)
        #expect(MacConnectionState.connected.isConnected == true)
        #expect(MacConnectionState.error("test").isConnected == false)
    }

    @Test("Connection state display text")
    func displayText() {
        #expect(MacConnectionState.disconnected.displayText == "Disconnected")
        #expect(MacConnectionState.connecting.displayText == "Connecting…")
        #expect(MacConnectionState.connected.displayText == "Connected")
        #expect(MacConnectionState.error("Network error").displayText == "Error: Network error")
    }

    @Test("Connection state equality")
    func equality() {
        #expect(MacConnectionState.disconnected == .disconnected)
        #expect(MacConnectionState.connecting == .connecting)
        #expect(MacConnectionState.connected == .connected)
        #expect(MacConnectionState.error("test") == .error("test"))
        #expect(MacConnectionState.error("test") != .error("other"))
        #expect(MacConnectionState.disconnected != .connecting)
    }
}

// MARK: - DiscoveredMac Tests

@Suite("DiscoveredMac Tests")
struct DiscoveredMacTests {

    @Test("DiscoveredMac has unique IDs")
    func uniqueIDs() {
        let endpoint = NWEndpoint.hostPort(host: "192.168.1.100", port: 8080)
        let a = DiscoveredMac(id: "mac1", name: "Test Mac", endpoint: endpoint)
        let b = DiscoveredMac(id: "mac2", name: "Test Mac", endpoint: endpoint)
        #expect(a.id != b.id)
    }

    @Test("DiscoveredMac equality")
    func equality() {
        let endpoint1 = NWEndpoint.hostPort(host: "192.168.1.100", port: 8080)
        let endpoint2 = NWEndpoint.hostPort(host: "192.168.1.101", port: 8080)

        let a = DiscoveredMac(id: "mac1", name: "Test Mac", endpoint: endpoint1)
        let b = DiscoveredMac(id: "mac1", name: "Test Mac", endpoint: endpoint2)
        let c = DiscoveredMac(id: "mac2", name: "Test Mac", endpoint: endpoint1)
        let d = DiscoveredMac(id: "mac1", name: "Other Mac", endpoint: endpoint1)

        #expect(a == b) // Same id and name, different endpoint
        #expect(a != c) // Different id
        #expect(a != d) // Different name
    }
}

// MARK: - CompanionMessage Payload Tests

@Suite("CompanionMessage Payload Tests")
struct CompanionMessagePayloadTests {

    @Test("StatusUpdatePayload encodes and decodes")
    func statusUpdatePayload() throws {
        let payload = StatusUpdatePayload(
            isMonitoring: true,
            onlineTargets: 5,
            offlineTargets: 2,
            averageLatency: 15.5,
            timestamp: Date()
        )

        let message = CompanionMessage.statusUpdate(payload)
        let encoded = try message.encodeLengthPrefixed()
        #expect(encoded.count > 4) // Should have length prefix + JSON

        // Verify length prefix
        let length = encoded.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        #expect(Int(length) == encoded.count - 4)
    }

    @Test("CommandPayload encodes and decodes")
    func commandPayload() throws {
        let payload = CommandPayload(action: .scanDevices, parameters: ["subnet": "192.168.1"])
        let message = CompanionMessage.command(payload)
        let encoded = try message.encodeLengthPrefixed()
        #expect(encoded.count > 4)
    }

    @Test("HeartbeatPayload encodes and decodes")
    func heartbeatPayload() throws {
        let payload = HeartbeatPayload(timestamp: Date(), version: "1.0")
        let message = CompanionMessage.heartbeat(payload)
        let encoded = try message.encodeLengthPrefixed()
        #expect(encoded.count > 4)
    }

    @Test("ErrorPayload encodes and decodes")
    func errorPayload() throws {
        let payload = ErrorPayload(code: "E001", message: "Connection failed", timestamp: Date())
        let message = CompanionMessage.error(payload)
        let encoded = try message.encodeLengthPrefixed()
        #expect(encoded.count > 4)
    }

    @Test("All CommandAction cases are defined")
    func commandActions() {
        let actions: [CommandAction] = [
            .startMonitoring, .stopMonitoring, .scanDevices,
            .ping, .traceroute, .portScan, .dnsLookup,
            .wakeOnLan, .refreshTargets, .refreshDevices
        ]
        #expect(actions.count == 10)
    }
}

// MARK: - Import Statement for Network Framework

import Network
