import Testing
import Foundation
@testable import Netmonitor

// MARK: - Mock Services

@MainActor
final class MockWHOISService: WHOISServiceProtocol {
    nonisolated func lookup(query: String) async throws -> WHOISResult {
        if query == "error.com" {
            throw NetworkError.connectionFailed
        }
        return WHOISResult(
            query: query,
            registrar: "Mock Registrar",
            nameServers: ["ns1.mock.com", "ns2.mock.com"],
            status: ["active"],
            rawData: "Mock raw WHOIS data for \(query)"
        )
    }
}

@MainActor
final class MockGatewayServiceForVM: GatewayServiceProtocol {
    var gateway: GatewayInfo? = GatewayInfo(ipAddress: "192.168.1.1", latency: 5.0)
    var isLoading: Bool = false

    func detectGateway() async {
        gateway = GatewayInfo(ipAddress: "192.168.1.1", latency: 5.0)
    }
}

@MainActor
final class MockNetworkMonitorServiceForVM: NetworkMonitorServiceProtocol {
    var isConnected: Bool = true
    var connectionType: ConnectionType = .wifi
    var isExpensive: Bool = false
    var isConstrained: Bool = false
    var statusText: String = "Connected via WiFi"

    func startMonitoring() {}
    func stopMonitoring() {}
}

@MainActor
final class MockWiFiInfoServiceForVM: WiFiInfoServiceProtocol {
    var currentWiFi: WiFiInfo? = WiFiInfo(ssid: "TestNetwork", signalDBm: -45)
    var isLocationAuthorized: Bool = true

    func requestLocationPermission() {}
    func refreshWiFiInfo() {}
}

@MainActor
final class MockPublicIPServiceForVM: PublicIPServiceProtocol {
    var ispInfo: ISPInfo? = ISPInfo(publicIP: "1.2.3.4", ispName: "Mock ISP")
    var isLoading: Bool = false

    func fetchPublicIP(forceRefresh: Bool) async {}
}

@MainActor
final class MockDeviceDiscoveryServiceForVM: DeviceDiscoveryServiceProtocol {
    var discoveredDevices: [DiscoveredDevice] = [
        DiscoveredDevice(ipAddress: "192.168.1.10", latency: 5.0, discoveredAt: Date()),
        DiscoveredDevice(ipAddress: "192.168.1.11", latency: 12.0, discoveredAt: Date())
    ]
    var isScanning: Bool = false
    var scanProgress: Double = 0
    var scanPhase: ScanDisplayPhase = .idle
    var lastScanDate: Date? = Date()

    nonisolated func scanNetwork(subnet: String?) async {}
    func stopScan() {}
}

@MainActor
final class MockMacConnectionServiceForVM: MacConnectionServiceProtocol {
    var connectionState: MacConnectionState = .disconnected
    var discoveredMacs: [DiscoveredMac] = []
    var isBrowsing: Bool = false
    var connectedMacName: String? = nil
    var lastStatusUpdate: StatusUpdatePayload? = nil
    var lastTargetList: TargetListPayload? = nil
    var lastDeviceList: DeviceListPayload? = nil

    func startBrowsing() {}
    func stopBrowsing() {}
    func connect(to mac: DiscoveredMac) {}
    func connectDirect(host: String, port: UInt16) {}
    func disconnect() {}
    func send(command: CommandPayload) async {}
}

@MainActor
final class MockPingServiceForVM: PingServiceProtocol {
    nonisolated func ping(host: String, count: Int, timeout: TimeInterval) async -> AsyncStream<PingResult> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    nonisolated func stop() async {}
    nonisolated func calculateStatistics(_ results: [PingResult], requestedCount: Int?) async -> PingStatistics? {
        nil
    }
}

@MainActor
final class MockPortScannerServiceForVM: PortScannerServiceProtocol {
    nonisolated func scan(host: String, ports: [Int], timeout: TimeInterval) async -> AsyncStream<PortScanResult> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
    nonisolated func stop() async {}
}

@MainActor
final class MockDNSLookupServiceForVM: DNSLookupServiceProtocol {
    var isLoading: Bool = false
    var lastError: String? = nil

    func lookup(domain: String, recordType: DNSRecordType, server: String?) async -> DNSQueryResult? {
        nil
    }
}

@MainActor
final class MockWakeOnLANServiceForVM: WakeOnLANServiceProtocol {
    var isSending: Bool = false
    var lastResult: WakeOnLANResult? = nil
    var lastError: String? = nil

    func wake(macAddress: String, broadcastAddress: String, port: UInt16) async -> Bool {
        true
    }
}

@MainActor
final class MockSpeedTestServiceForVM: SpeedTestServiceProtocol {
    var downloadSpeed: Double = 0
    var uploadSpeed: Double = 0
    var latency: Double = 0
    var progress: Double = 0
    var phase: SpeedTestPhase = .idle
    var isRunning: Bool = false
    var errorMessage: String? = nil
    var duration: TimeInterval = 5.0

    func startTest() async throws -> SpeedTestData {
        SpeedTestData(downloadSpeed: 100.0, uploadSpeed: 50.0, latency: 15.0, serverName: "Mock Server")
    }
    func stopTest() {
        isRunning = false
        phase = .idle
    }
}

// MARK: - WHOISToolViewModel Tests

@Suite("WHOISToolViewModel Tests")
@MainActor
struct WHOISToolViewModelTests {

    @Test("Initial state is correct")
    func initialState() {
        let vm = WHOISToolViewModel(whoisService: MockWHOISService())

        #expect(vm.domain == "")
        #expect(vm.isLoading == false)
        #expect(vm.result == nil)
        #expect(vm.errorMessage == nil)
    }

    @Test("canStartLookup is false when domain is empty")
    func canStartLookupEmpty() {
        let vm = WHOISToolViewModel(whoisService: MockWHOISService())

        #expect(vm.canStartLookup == false)
    }

    @Test("canStartLookup is false when domain is only whitespace")
    func canStartLookupWhitespace() {
        let vm = WHOISToolViewModel(whoisService: MockWHOISService())
        vm.domain = "   "

        #expect(vm.canStartLookup == false)
    }

    @Test("canStartLookup is true when domain has text")
    func canStartLookupWithDomain() {
        let vm = WHOISToolViewModel(whoisService: MockWHOISService())
        vm.domain = "example.com"

        #expect(vm.canStartLookup == true)
    }

    @Test("canStartLookup is false when loading")
    func canStartLookupWhileLoading() {
        let vm = WHOISToolViewModel(whoisService: MockWHOISService())
        vm.domain = "example.com"
        vm.isLoading = true

        #expect(vm.canStartLookup == false)
    }

    @Test("clearResults resets result and error")
    func clearResults() {
        let vm = WHOISToolViewModel(whoisService: MockWHOISService())
        vm.errorMessage = "Some error"

        vm.clearResults()

        #expect(vm.result == nil)
        #expect(vm.errorMessage == nil)
    }

    @Test("lookup sets result on success")
    func lookupSuccess() async {
        let vm = WHOISToolViewModel(whoisService: MockWHOISService())
        vm.domain = "example.com"

        await vm.lookup()

        #expect(vm.result != nil)
        #expect(vm.result?.query == "example.com")
        #expect(vm.result?.registrar == "Mock Registrar")
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("lookup sets error on failure")
    func lookupError() async {
        let vm = WHOISToolViewModel(whoisService: MockWHOISService())
        vm.domain = "error.com"

        await vm.lookup()

        #expect(vm.result == nil)
        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    @Test("lookup does nothing when canStartLookup is false")
    func lookupSkipsWhenCannotStart() async {
        let vm = WHOISToolViewModel(whoisService: MockWHOISService())
        vm.domain = ""

        await vm.lookup()

        #expect(vm.result == nil)
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }
}

// MARK: - ToolsViewModel Tests

@Suite("ToolsViewModel Tests")
@MainActor
struct ToolsViewModelTests {

    @Test("Initial state is correct")
    func initialState() {
        let vm = ToolsViewModel(
            pingService: MockPingServiceForVM(),
            portScannerService: MockPortScannerServiceForVM(),
            dnsLookupService: MockDNSLookupServiceForVM(),
            wakeOnLANService: MockWakeOnLANServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockGatewayServiceForVM()
        )

        #expect(vm.recentResults.isEmpty)
        #expect(vm.isPingRunning == false)
        #expect(vm.isPortScanRunning == false)
        #expect(vm.currentPingResults.isEmpty)
        #expect(vm.currentPortScanResults.isEmpty)
        #expect(vm.lastGatewayResult == nil)
    }

    @Test("isScanning delegates to device discovery service")
    func isScanningDelegation() {
        let mockDiscovery = MockDeviceDiscoveryServiceForVM()
        let vm = ToolsViewModel(
            pingService: MockPingServiceForVM(),
            portScannerService: MockPortScannerServiceForVM(),
            dnsLookupService: MockDNSLookupServiceForVM(),
            wakeOnLANService: MockWakeOnLANServiceForVM(),
            deviceDiscoveryService: mockDiscovery,
            gatewayService: MockGatewayServiceForVM()
        )

        #expect(vm.isScanning == false)

        mockDiscovery.isScanning = true
        #expect(vm.isScanning == true)
    }

    @Test("clearActivity removes all results")
    func clearActivity() {
        let vm = ToolsViewModel(
            pingService: MockPingServiceForVM(),
            portScannerService: MockPortScannerServiceForVM(),
            dnsLookupService: MockDNSLookupServiceForVM(),
            wakeOnLANService: MockWakeOnLANServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockGatewayServiceForVM()
        )

        // Run DNS lookup to add activity
        Task {
            _ = await vm.runDNSLookup(domain: "example.com")
        }

        // Clear
        vm.clearActivity()
        #expect(vm.recentResults.isEmpty)
    }

    @Test("DI allows injecting all services")
    func dependencyInjection() {
        let mockPing = MockPingServiceForVM()
        let mockPort = MockPortScannerServiceForVM()
        let mockDNS = MockDNSLookupServiceForVM()
        let mockWOL = MockWakeOnLANServiceForVM()
        let mockDiscovery = MockDeviceDiscoveryServiceForVM()
        let mockGateway = MockGatewayServiceForVM()

        let vm = ToolsViewModel(
            pingService: mockPing,
            portScannerService: mockPort,
            dnsLookupService: mockDNS,
            wakeOnLANService: mockWOL,
            deviceDiscoveryService: mockDiscovery,
            gatewayService: mockGateway
        )

        #expect(vm.pingService is MockPingServiceForVM)
        #expect(vm.portScannerService is MockPortScannerServiceForVM)
        #expect(vm.dnsLookupService is MockDNSLookupServiceForVM)
        #expect(vm.wakeOnLANService is MockWakeOnLANServiceForVM)
        #expect(vm.deviceDiscoveryService is MockDeviceDiscoveryServiceForVM)
        #expect(vm.gatewayService is MockGatewayServiceForVM)
    }

    @Test("runDNSLookup adds activity item on nil result")
    func dnsLookupAddsFailedActivity() async {
        let vm = ToolsViewModel(
            pingService: MockPingServiceForVM(),
            portScannerService: MockPortScannerServiceForVM(),
            dnsLookupService: MockDNSLookupServiceForVM(),
            wakeOnLANService: MockWakeOnLANServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockGatewayServiceForVM()
        )

        let result = await vm.runDNSLookup(domain: "example.com")

        #expect(result == nil)
        #expect(vm.recentResults.count == 1)
        #expect(vm.recentResults[0].tool == "DNS Lookup")
        #expect(vm.recentResults[0].target == "example.com")
        #expect(vm.recentResults[0].success == false)
    }

    @Test("sendWakeOnLAN adds activity item")
    func wolAddsActivity() async {
        let vm = ToolsViewModel(
            pingService: MockPingServiceForVM(),
            portScannerService: MockPortScannerServiceForVM(),
            dnsLookupService: MockDNSLookupServiceForVM(),
            wakeOnLANService: MockWakeOnLANServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockGatewayServiceForVM()
        )

        let success = await vm.sendWakeOnLAN(macAddress: "AA:BB:CC:DD:EE:FF")

        #expect(success == true)
        #expect(vm.recentResults.count == 1)
        #expect(vm.recentResults[0].tool == "Wake on LAN")
        #expect(vm.recentResults[0].success == true)
    }

    @Test("Activity list caps at 20 items")
    func activityCapsAt20() async {
        let vm = ToolsViewModel(
            pingService: MockPingServiceForVM(),
            portScannerService: MockPortScannerServiceForVM(),
            dnsLookupService: MockDNSLookupServiceForVM(),
            wakeOnLANService: MockWakeOnLANServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockGatewayServiceForVM()
        )

        // Add 25 items by calling WOL 25 times
        for _ in 0..<25 {
            _ = await vm.sendWakeOnLAN(macAddress: "AA:BB:CC:DD:EE:FF")
        }

        #expect(vm.recentResults.count == 20)
    }
}

// MARK: - DashboardViewModel Tests

@Suite("DashboardViewModel Tests")
@MainActor
struct DashboardViewModelTests {

    @Test("Initial state is correct")
    func initialState() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.isRefreshing == false)
        #expect(vm.sessionStartTime.timeIntervalSinceNow < 1)
    }

    @Test("isConnected delegates to network monitor")
    func isConnectedDelegation() {
        let mockMonitor = MockNetworkMonitorServiceForVM()
        let vm = DashboardViewModel(
            networkMonitor: mockMonitor,
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.isConnected == true)

        mockMonitor.isConnected = false
        #expect(vm.isConnected == false)
    }

    @Test("connectionType delegates to network monitor")
    func connectionTypeDelegation() {
        let mockMonitor = MockNetworkMonitorServiceForVM()
        let vm = DashboardViewModel(
            networkMonitor: mockMonitor,
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.connectionType == .wifi)

        mockMonitor.connectionType = .ethernet
        #expect(vm.connectionType == .ethernet)
    }

    @Test("connectionStatusText delegates to network monitor")
    func connectionStatusTextDelegation() {
        let mockMonitor = MockNetworkMonitorServiceForVM()
        let vm = DashboardViewModel(
            networkMonitor: mockMonitor,
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.connectionStatusText == "Connected via WiFi")
    }

    @Test("currentWiFi delegates to WiFi service")
    func currentWiFiDelegation() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.currentWiFi?.ssid == "TestNetwork")
    }

    @Test("gateway delegates to gateway service")
    func gatewayDelegation() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.gateway?.ipAddress == "192.168.1.1")
    }

    @Test("ispInfo delegates to public IP service")
    func ispInfoDelegation() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.ispInfo?.publicIP == "1.2.3.4")
        #expect(vm.ispInfo?.ispName == "Mock ISP")
    }

    @Test("deviceCount returns discovered device count")
    func deviceCount() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.deviceCount == 2)
        #expect(vm.discoveredDevices.count == 2)
    }

    @Test("isScanning delegates to device discovery")
    func isScanningDelegation() {
        let mockDiscovery = MockDeviceDiscoveryServiceForVM()
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: mockDiscovery,
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.isScanning == false)

        mockDiscovery.isScanning = true
        #expect(vm.isScanning == true)
    }

    @Test("sessionDuration formats minutes correctly")
    func sessionDurationMinutes() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        // Just started, should show 0m
        #expect(vm.sessionDuration == "0m")
    }

    @Test("sessionDuration is a valid string")
    func sessionDurationFormat() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        // sessionStartTime is private(set), so just verify format is valid
        let duration = vm.sessionDuration
        #expect(duration.contains("m"))
    }

    @Test("sessionStartTimeFormatted includes Today prefix")
    func sessionStartTimeFormatted() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.sessionStartTimeFormatted.hasPrefix("Today, "))
    }

    @Test("needsLocationPermission delegates to WiFi service")
    func needsLocationPermission() {
        let mockWiFi = MockWiFiInfoServiceForVM()
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: mockWiFi,
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.needsLocationPermission == false) // isLocationAuthorized = true

        mockWiFi.isLocationAuthorized = false
        #expect(vm.needsLocationPermission == true)
    }

    @Test("stopDeviceScan delegates to discovery service")
    func stopDeviceScan() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        // Should not crash
        vm.stopDeviceScan()
    }

    @Test("lastScanDate delegates to discovery service")
    func lastScanDate() {
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        #expect(vm.lastScanDate != nil)
    }
}

// MARK: - SpeedTestToolViewModel Tests

@Suite("SpeedTestToolViewModel Tests")
@MainActor
struct SpeedTestToolViewModelTests {

    @Test("Initial state is correct")
    func initialState() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())

        #expect(vm.isRunning == false)
        #expect(vm.downloadSpeed == 0)
        #expect(vm.uploadSpeed == 0)
        #expect(vm.latency == 0)
        #expect(vm.progress == 0)
        #expect(vm.phase == .idle)
        #expect(vm.errorMessage == nil)
    }

    @Test("phaseText returns Ready for idle")
    func phaseTextIdle() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.phase = .idle

        #expect(vm.phaseText == "Ready")
    }

    @Test("phaseText returns correct text for latency phase")
    func phaseTextLatency() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.phase = .latency

        #expect(vm.phaseText == "Measuring latency...")
    }

    @Test("phaseText returns correct text for download phase")
    func phaseTextDownload() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.phase = .download

        #expect(vm.phaseText == "Testing download...")
    }

    @Test("phaseText returns correct text for upload phase")
    func phaseTextUpload() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.phase = .upload

        #expect(vm.phaseText == "Testing upload...")
    }

    @Test("phaseText returns Complete for complete phase")
    func phaseTextComplete() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.phase = .complete

        #expect(vm.phaseText == "Complete")
    }

    @Test("downloadSpeedText formats Mbps correctly")
    func downloadSpeedMbps() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.downloadSpeed = 95.3

        #expect(vm.downloadSpeedText == "95.3 Mbps")
    }

    @Test("downloadSpeedText formats Gbps correctly")
    func downloadSpeedGbps() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.downloadSpeed = 1500.0

        #expect(vm.downloadSpeedText == "1.5 Gbps")
    }

    @Test("uploadSpeedText formats Mbps correctly")
    func uploadSpeedMbps() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.uploadSpeed = 25.7

        #expect(vm.uploadSpeedText == "25.7 Mbps")
    }

    @Test("uploadSpeedText formats Gbps correctly")
    func uploadSpeedGbps() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.uploadSpeed = 2000.0

        #expect(vm.uploadSpeedText == "2.0 Gbps")
    }

    @Test("latencyText formats correctly")
    func latencyText() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.latency = 15.3

        #expect(vm.latencyText == "15 ms")
    }

    @Test("latencyText formats zero correctly")
    func latencyTextZero() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())

        #expect(vm.latencyText == "0 ms")
    }

    @Test("stopTest resets state")
    func stopTestResetsState() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.isRunning = true
        vm.phase = .download

        vm.stopTest()

        #expect(vm.isRunning == false)
        #expect(vm.phase == .idle)
    }

    @Test("Speed at 1000 Mbps boundary shows Gbps")
    func speedAtBoundary() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.downloadSpeed = 1000.0

        #expect(vm.downloadSpeedText == "1.0 Gbps")
    }

    @Test("Speed just below 1000 Mbps shows Mbps")
    func speedBelowBoundary() {
        let vm = SpeedTestToolViewModel(service: MockSpeedTestServiceForVM())
        vm.downloadSpeed = 999.9

        #expect(vm.downloadSpeedText == "999.9 Mbps")
    }

    @Test("DI allows injecting mock service")
    func dependencyInjection() {
        let mock = MockSpeedTestServiceForVM()
        let vm = SpeedTestToolViewModel(service: mock)

        #expect(vm.isRunning == false)
    }
}

// MARK: - ToolActivityItem Additional Tests

@Suite("ToolActivityItem Extended Tests")
struct ToolActivityItemExtendedTests {

    @Test("timeAgoText for recent timestamp")
    func timeAgoRecent() {
        let item = ToolActivityItem(
            tool: "Ping",
            target: "8.8.8.8",
            result: "OK",
            success: true,
            timestamp: Date()
        )

        #expect(item.timeAgoText == "Just now")
    }

    @Test("timeAgoText for 5 minutes ago")
    func timeAgo5Minutes() {
        let item = ToolActivityItem(
            tool: "Ping",
            target: "8.8.8.8",
            result: "OK",
            success: true,
            timestamp: Date().addingTimeInterval(-300)
        )

        #expect(item.timeAgoText == "5 min ago")
    }

    @Test("timeAgoText for 1 hour ago")
    func timeAgo1Hour() {
        let item = ToolActivityItem(
            tool: "Ping",
            target: "8.8.8.8",
            result: "OK",
            success: true,
            timestamp: Date().addingTimeInterval(-3600)
        )

        #expect(item.timeAgoText == "1 hour ago")
    }

    @Test("timeAgoText for 3 hours ago")
    func timeAgo3Hours() {
        let item = ToolActivityItem(
            tool: "Ping",
            target: "8.8.8.8",
            result: "OK",
            success: true,
            timestamp: Date().addingTimeInterval(-10800)
        )

        #expect(item.timeAgoText == "3 hours ago")
    }

    @Test("timeAgoText for 1 day ago")
    func timeAgo1Day() {
        let item = ToolActivityItem(
            tool: "Ping",
            target: "8.8.8.8",
            result: "OK",
            success: true,
            timestamp: Date().addingTimeInterval(-86400)
        )

        #expect(item.timeAgoText == "1 day ago")
    }

    @Test("timeAgoText for 3 days ago")
    func timeAgo3Days() {
        let item = ToolActivityItem(
            tool: "Ping",
            target: "8.8.8.8",
            result: "OK",
            success: true,
            timestamp: Date().addingTimeInterval(-259200)
        )

        #expect(item.timeAgoText == "3 days ago")
    }

    @Test("ToolActivityItem has unique IDs")
    func uniqueIDs() {
        let item1 = ToolActivityItem(tool: "Ping", target: "a", result: "OK", success: true, timestamp: Date())
        let item2 = ToolActivityItem(tool: "Ping", target: "a", result: "OK", success: true, timestamp: Date())

        #expect(item1.id != item2.id)
    }
}

// NOTE: MacConnectionState, ScanDisplayPhase, SpeedTestPhase tests are in ServiceTestsBatch3.swift

// MARK: - WHOISResult Additional Tests

@Suite("WHOISResult Extended Tests")
struct WHOISResultExtendedTests {

    @Test("domainAge returns years correctly")
    func domainAge() {
        let threeYearsAgo = Calendar.current.date(byAdding: .year, value: -3, to: Date())!
        let result = WHOISResult(
            query: "example.com",
            creationDate: threeYearsAgo,
            rawData: "test"
        )

        #expect(result.domainAge == "3 years")
    }

    @Test("domainAge returns nil when no creation date")
    func domainAgeNil() {
        let result = WHOISResult(query: "example.com", rawData: "test")

        #expect(result.domainAge == nil)
    }

    @Test("daysUntilExpiration returns positive for future date")
    func daysUntilExpirationFuture() {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let result = WHOISResult(
            query: "example.com",
            expirationDate: futureDate,
            rawData: "test"
        )

        let days = result.daysUntilExpiration
        #expect(days != nil)
        #expect(days! >= 29 && days! <= 31)
    }

    @Test("daysUntilExpiration returns nil when no expiration date")
    func daysUntilExpirationNil() {
        let result = WHOISResult(query: "example.com", rawData: "test")

        #expect(result.daysUntilExpiration == nil)
    }

    @Test("daysUntilExpiration returns negative for past date")
    func daysUntilExpirationPast() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let result = WHOISResult(
            query: "example.com",
            expirationDate: pastDate,
            rawData: "test"
        )

        let days = result.daysUntilExpiration
        #expect(days != nil)
        #expect(days! < 0)
    }
}

// MARK: - GatewayInfo Tests

@Suite("GatewayInfo Tests")
struct GatewayInfoTests {

    @Test("latencyText returns nil when latency is nil")
    func latencyTextNil() {
        let info = GatewayInfo(ipAddress: "192.168.1.1")

        #expect(info.latencyText == nil)
    }

    @Test("latencyText returns <1 ms for sub-millisecond")
    func latencyTextSubMs() {
        let info = GatewayInfo(ipAddress: "192.168.1.1", latency: 0.5)

        #expect(info.latencyText == "<1 ms")
    }

    @Test("latencyText formats normal latency")
    func latencyTextNormal() {
        let info = GatewayInfo(ipAddress: "192.168.1.1", latency: 15.7)

        #expect(info.latencyText == "16 ms")
    }
}

// MARK: - ISPInfo Tests

@Suite("ISPInfo Tests")
struct ISPInfoTests {

    @Test("locationText returns city and country")
    func locationTextCityCountry() {
        let info = ISPInfo(publicIP: "1.2.3.4", city: "Austin", country: "United States", countryCode: "US")

        #expect(info.locationText == "Austin, US")
    }

    @Test("locationText prefers countryCode over country")
    func locationTextPreferCode() {
        let info = ISPInfo(publicIP: "1.2.3.4", city: "London", country: "United Kingdom", countryCode: "GB")

        #expect(info.locationText == "London, GB")
    }

    @Test("locationText returns nil when both are nil")
    func locationTextNil() {
        let info = ISPInfo(publicIP: "1.2.3.4")

        #expect(info.locationText == nil)
    }

    @Test("locationText returns country only when city is nil")
    func locationTextCountryOnly() {
        let info = ISPInfo(publicIP: "1.2.3.4", countryCode: "US")

        #expect(info.locationText == "US")
    }
}

// MARK: - WiFiInfo Tests

@Suite("WiFiInfo Extended Tests")
struct WiFiInfoExtendedTests {

    @Test("signalQuality returns excellent for strong signal")
    func signalQualityExcellent() {
        let info = WiFiInfo(ssid: "Test", signalDBm: -40)

        #expect(info.signalQuality == .excellent)
    }

    @Test("signalQuality returns good for moderate signal")
    func signalQualityGood() {
        let info = WiFiInfo(ssid: "Test", signalDBm: -55)

        #expect(info.signalQuality == .good)
    }

    @Test("signalQuality returns fair for weak signal")
    func signalQualityFair() {
        let info = WiFiInfo(ssid: "Test", signalDBm: -65)

        #expect(info.signalQuality == .fair)
    }

    @Test("signalQuality returns poor for very weak signal")
    func signalQualityPoor() {
        let info = WiFiInfo(ssid: "Test", signalDBm: -85)

        #expect(info.signalQuality == .poor)
    }

    @Test("signalQuality returns unknown when no signal data")
    func signalQualityUnknown() {
        let info = WiFiInfo(ssid: "Test")

        #expect(info.signalQuality == .unknown)
    }

    @Test("signalBars returns correct values")
    func signalBars() {
        #expect(WiFiInfo(ssid: "T", signalDBm: -40).signalBars == 4)
        #expect(WiFiInfo(ssid: "T", signalDBm: -55).signalBars == 3)
        #expect(WiFiInfo(ssid: "T", signalDBm: -65).signalBars == 2)
        #expect(WiFiInfo(ssid: "T", signalDBm: -75).signalBars == 1)
        #expect(WiFiInfo(ssid: "T", signalDBm: -90).signalBars == 0)
        #expect(WiFiInfo(ssid: "T").signalBars == 0)
    }
}

// MARK: - DNSRecord TTL Tests

@Suite("DNSRecord TTL Tests")
struct DNSRecordTTLTests {

    @Test("ttlText formats days")
    func ttlDays() {
        let record = DNSRecord(name: "test", type: .a, value: "1.2.3.4", ttl: 172800)
        #expect(record.ttlText == "2d")
    }

    @Test("ttlText formats hours")
    func ttlHours() {
        let record = DNSRecord(name: "test", type: .a, value: "1.2.3.4", ttl: 7200)
        #expect(record.ttlText == "2h")
    }

    @Test("ttlText formats minutes")
    func ttlMinutes() {
        let record = DNSRecord(name: "test", type: .a, value: "1.2.3.4", ttl: 300)
        #expect(record.ttlText == "5m")
    }

    @Test("ttlText formats seconds")
    func ttlSeconds() {
        let record = DNSRecord(name: "test", type: .a, value: "1.2.3.4", ttl: 30)
        #expect(record.ttlText == "30s")
    }
}
