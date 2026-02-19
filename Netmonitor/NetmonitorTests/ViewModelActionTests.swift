import Testing
import Foundation
@testable import Netmonitor

// MARK: - Additional Mock Services
// NOTE: Base mocks (MockPingServiceForVM, MockPortScannerServiceForVM, etc.) are
// defined in ViewModelTests.swift and accessible here within the same test target.

// Ping mock that yields two results and returns statistics
@MainActor
final class MockPingServiceWithResults: PingServiceProtocol {
    nonisolated func ping(host: String, count: Int, timeout: TimeInterval) async -> AsyncStream<PingResult> {
        AsyncStream { continuation in
            continuation.yield(PingResult(sequence: 1, host: host, ttl: 64, time: 12.5))
            continuation.yield(PingResult(sequence: 2, host: host, ttl: 64, time: 13.2))
            continuation.finish()
        }
    }

    nonisolated func stop() async {}

    nonisolated func calculateStatistics(_ results: [PingResult], requestedCount: Int?) async -> PingStatistics? {
        PingStatistics(
            host: results.first?.host ?? "unknown",
            transmitted: 2,
            received: 2,
            packetLoss: 0,
            minTime: 12.5,
            maxTime: 13.2,
            avgTime: 12.85,
            stdDev: nil
        )
    }
}

// Port scanner mock that yields one open port
@MainActor
final class MockPortScannerWithOpenPort: PortScannerServiceProtocol {
    nonisolated func scan(host: String, ports: [Int], timeout: TimeInterval) async -> AsyncStream<PortScanResult> {
        AsyncStream { continuation in
            continuation.yield(PortScanResult(port: 80, state: .open))
            for port in ports where port != 80 {
                continuation.yield(PortScanResult(port: port, state: .closed))
            }
            continuation.finish()
        }
    }

    nonisolated func stop() async {}
}

// Traceroute mock that yields two hops
final class MockTracerouteServiceWithHops: TracerouteServiceProtocol {
    nonisolated func trace(host: String, maxHops: Int?, timeout: TimeInterval?) async -> AsyncStream<TracerouteHop> {
        AsyncStream { continuation in
            continuation.yield(TracerouteHop(hopNumber: 1, ipAddress: "192.168.1.1", times: [1.5, 1.6]))
            continuation.yield(TracerouteHop(hopNumber: 2, ipAddress: "10.0.0.1", times: [5.2, 5.4]))
            continuation.finish()
        }
    }

    nonisolated func stop() async {}
}

// DNS mock that returns a valid result
@MainActor
final class MockDNSServiceReturningResult: DNSLookupServiceProtocol {
    var isLoading: Bool = false
    var lastError: String? = nil

    func lookup(domain: String, recordType: DNSRecordType, server: String?) async -> DNSQueryResult? {
        DNSQueryResult(
            domain: domain,
            server: "8.8.8.8",
            queryType: recordType,
            records: [DNSRecord(name: domain, type: .a, value: "93.184.216.34", ttl: 300)],
            queryTime: 15.0
        )
    }
}

// DNS mock that returns nil with a custom error
@MainActor
final class MockDNSServiceWithError: DNSLookupServiceProtocol {
    var isLoading: Bool = false
    var lastError: String? = "DNS server unreachable"

    func lookup(domain: String, recordType: DNSRecordType, server: String?) async -> DNSQueryResult? {
        nil
    }
}

// Bonjour mock that tracks calls and controls isDiscovering
@MainActor
final class MockBonjourDiscoveryServiceForTests: BonjourDiscoveryServiceProtocol {
    var discoveredServices: [BonjourService] = []
    var isDiscovering: Bool = false
    var startDiscoveryCalled: Bool = false
    var stopDiscoveryCalled: Bool = false

    func discoveryStream(serviceType: String?) -> AsyncStream<BonjourService> {
        AsyncStream { $0.finish() }
    }

    func startDiscovery(serviceType: String?) {
        startDiscoveryCalled = true
        isDiscovering = true
    }

    func stopDiscovery() {
        stopDiscoveryCalled = true
        isDiscovering = false
    }

    nonisolated func resolveService(_ service: BonjourService) async -> BonjourService? {
        nil
    }
}

// Device discovery mock with actor-based call counting for sendable tracking
actor ScanCallCounter {
    var count = 0
    func increment() { count += 1 }
}

@MainActor
final class MockTrackingDeviceDiscovery: DeviceDiscoveryServiceProtocol {
    var discoveredDevices: [DiscoveredDevice] = []
    var isScanning: Bool = false
    var scanProgress: Double = 0
    var scanPhase: ScanDisplayPhase = .idle
    var lastScanDate: Date? = nil
    let scanCounter = ScanCallCounter()
    var stopScanCallCount: Int = 0

    nonisolated func scanNetwork(subnet: String?) async {
        await scanCounter.increment()
    }

    func stopScan() {
        stopScanCallCount += 1
    }
}

// Public IP mock that tracks the forceRefresh parameter
@MainActor
final class MockTrackingPublicIPService: PublicIPServiceProtocol {
    var ispInfo: ISPInfo? = nil
    var isLoading: Bool = false
    var lastForceRefresh: Bool? = nil

    func fetchPublicIP(forceRefresh: Bool) async {
        lastForceRefresh = forceRefresh
    }
}

// Gateway mock with no gateway (nil) for testing the "no gateway" path
@MainActor
final class MockNoGatewayService: GatewayServiceProtocol {
    var gateway: GatewayInfo? = nil
    var isLoading: Bool = false

    func detectGateway() async {}
}

// MARK: - PingToolViewModel Action Tests

@Suite("PingToolViewModel Action Tests")
@MainActor
struct PingToolViewModelActionTests {

    @Test("canStartPing is false when host is empty")
    func canStartPingEmptyHost() {
        let vm = PingToolViewModel(pingService: MockPingServiceForVM())
        #expect(vm.canStartPing == false)
    }

    @Test("canStartPing is false when host is only whitespace")
    func canStartPingWhitespace() {
        let vm = PingToolViewModel(pingService: MockPingServiceForVM())
        vm.host = "   "
        #expect(vm.canStartPing == false)
    }

    @Test("canStartPing is true when host is set and not running")
    func canStartPingWithValidHost() {
        let vm = PingToolViewModel(pingService: MockPingServiceForVM())
        vm.host = "8.8.8.8"
        #expect(vm.canStartPing == true)
    }

    @Test("canStartPing is false when isRunning is true")
    func canStartPingWhileRunning() {
        let vm = PingToolViewModel(pingService: MockPingServiceForVM())
        vm.host = "8.8.8.8"
        vm.isRunning = true
        #expect(vm.canStartPing == false)
    }

    @Test("startPing populates results from mock stream")
    func startPingPopulatesResults() async throws {
        let vm = PingToolViewModel(pingService: MockPingServiceWithResults())
        vm.host = "8.8.8.8"
        vm.startPing()

        // Allow the internal Task to run to completion
        try await Task.sleep(for: .milliseconds(200))

        #expect(vm.results.count == 2)
        #expect(vm.isRunning == false)
    }

    @Test("startPing computes statistics after completion")
    func startPingComputesStatistics() async throws {
        let vm = PingToolViewModel(pingService: MockPingServiceWithResults())
        vm.host = "8.8.8.8"
        vm.startPing()

        try await Task.sleep(for: .milliseconds(200))

        #expect(vm.statistics != nil)
        #expect(vm.statistics?.received == 2)
        #expect(vm.statistics?.transmitted == 2)
    }

    @Test("stopPing sets isRunning to false immediately")
    func stopPingSetsIsRunningFalse() {
        let vm = PingToolViewModel(pingService: MockPingServiceForVM())
        vm.host = "8.8.8.8"
        vm.startPing()
        #expect(vm.isRunning == true)
        vm.stopPing()
        #expect(vm.isRunning == false)
    }

    @Test("clearResults removes all results and statistics")
    func clearResultsRemovesAll() {
        let vm = PingToolViewModel(pingService: MockPingServiceForVM())
        vm.errorMessage = "some error"
        vm.clearResults()
        #expect(vm.results.isEmpty)
        #expect(vm.statistics == nil)
        #expect(vm.errorMessage == nil)
    }
}

// MARK: - PortScannerToolViewModel Tests

@Suite("PortScannerToolViewModel Action Tests")
@MainActor
struct PortScannerToolViewModelActionTests {

    @Test("canStartScan is false when host is empty")
    func canStartScanEmptyHost() {
        let vm = PortScannerToolViewModel(portScannerService: MockPortScannerServiceForVM())
        #expect(vm.canStartScan == false)
    }

    @Test("effectivePorts returns preset ports for web preset")
    func effectivePortsForWebPreset() {
        let vm = PortScannerToolViewModel(portScannerService: MockPortScannerServiceForVM())
        vm.portPreset = .web
        #expect(vm.effectivePorts == PortScanPreset.webPorts)
    }

    @Test("effectivePorts returns custom range ports when preset is custom")
    func effectivePortsForCustomRange() {
        let vm = PortScannerToolViewModel(portScannerService: MockPortScannerServiceForVM())
        vm.portPreset = .custom
        vm.customRange = PortRange(start: 80, end: 90)
        #expect(vm.effectivePorts == Array(80...90))
    }

    @Test("effectivePorts is empty when custom range is invalid (start greater than end)")
    func effectivePortsForInvalidCustomRange() {
        let vm = PortScannerToolViewModel(portScannerService: MockPortScannerServiceForVM())
        vm.portPreset = .custom
        vm.customRange = PortRange(start: 100, end: 50)
        #expect(vm.effectivePorts.isEmpty)
    }

    @Test("canStartScan is false when custom range is invalid")
    func canStartScanInvalidCustomRange() {
        let vm = PortScannerToolViewModel(portScannerService: MockPortScannerServiceForVM())
        vm.host = "192.168.1.1"
        vm.portPreset = .custom
        vm.customRange = PortRange(start: 100, end: 50)
        #expect(vm.canStartScan == false)
    }

    @Test("progress computes correctly from scannedCount and totalPorts")
    func progressComputed() {
        let vm = PortScannerToolViewModel(portScannerService: MockPortScannerServiceForVM())
        vm.portPreset = .web  // 7 ports
        vm.scannedCount = 3
        let expected = 3.0 / Double(PortScanPreset.webPorts.count)
        #expect(abs(vm.progress - expected) < 0.001)
    }

    @Test("startScan sets isRunning to true")
    func startScanSetsIsRunning() {
        let vm = PortScannerToolViewModel(portScannerService: MockPortScannerServiceForVM())
        vm.host = "192.168.1.1"
        vm.portPreset = .web
        vm.startScan()
        #expect(vm.isRunning == true)
        vm.stopScan()
    }

    @Test("stopScan sets isRunning to false")
    func stopScanSetsIsRunningFalse() {
        let vm = PortScannerToolViewModel(portScannerService: MockPortScannerServiceForVM())
        vm.host = "192.168.1.1"
        vm.portPreset = .web
        vm.startScan()
        vm.stopScan()
        #expect(vm.isRunning == false)
    }
}

// MARK: - TracerouteToolViewModel Action Tests

@Suite("TracerouteToolViewModel Action Tests")
@MainActor
struct TracerouteToolViewModelActionTests {

    @Test("canStartTrace is false when host is empty")
    func canStartTraceEmptyHost() {
        let vm = TracerouteToolViewModel(tracerouteService: MockTracerouteServiceWithHops())
        #expect(vm.canStartTrace == false)
    }

    @Test("canStartTrace is true when host is set and not running")
    func canStartTraceWithHost() {
        let vm = TracerouteToolViewModel(tracerouteService: MockTracerouteServiceWithHops())
        vm.host = "8.8.8.8"
        #expect(vm.canStartTrace == true)
    }

    @Test("startTrace populates hops from mock stream")
    func startTracePopulatesHops() async throws {
        let vm = TracerouteToolViewModel(tracerouteService: MockTracerouteServiceWithHops())
        vm.host = "8.8.8.8"
        vm.startTrace()

        try await Task.sleep(for: .milliseconds(200))

        #expect(vm.hops.count == 2)
        #expect(vm.hops[0].hopNumber == 1)
        #expect(vm.hops[1].hopNumber == 2)
        #expect(vm.isRunning == false)
    }

    @Test("stopTrace sets isRunning to false")
    func stopTraceSetsIsRunningFalse() {
        // Use the slow-finishing base mock so trace stays in progress
        let vm = TracerouteToolViewModel(tracerouteService: MockTracerouteServiceWithHops())
        vm.host = "8.8.8.8"
        vm.startTrace()
        #expect(vm.isRunning == true)
        vm.stopTrace()
        #expect(vm.isRunning == false)
    }
}

// MARK: - DNSLookupToolViewModel Action Tests

@Suite("DNSLookupToolViewModel Action Tests")
@MainActor
struct DNSLookupToolViewModelActionTests {

    @Test("lookup with result-returning mock populates result")
    func lookupSuccess() async {
        let vm = DNSLookupToolViewModel(dnsService: MockDNSServiceReturningResult())
        vm.domain = "example.com"

        await vm.lookup()

        #expect(vm.result != nil)
        #expect(vm.result?.domain == "example.com")
        #expect(vm.result?.records.count == 1)
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test("lookup with nil-returning mock sets errorMessage to fallback")
    func lookupFailureFallbackError() async {
        let vm = DNSLookupToolViewModel(dnsService: MockDNSLookupServiceForVM())
        vm.domain = "nonexistent.example"

        await vm.lookup()

        #expect(vm.result == nil)
        #expect(vm.errorMessage == "Lookup failed")
        #expect(vm.isLoading == false)
    }

    @Test("lookup with error mock uses custom error message")
    func lookupFailureCustomError() async {
        let vm = DNSLookupToolViewModel(dnsService: MockDNSServiceWithError())
        vm.domain = "unreachable.example"

        await vm.lookup()

        #expect(vm.result == nil)
        #expect(vm.errorMessage == "DNS server unreachable")
        #expect(vm.isLoading == false)
    }
}

// MARK: - BonjourDiscoveryToolViewModel Action Tests

@Suite("BonjourDiscoveryToolViewModel Action Tests")
@MainActor
struct BonjourDiscoveryToolViewModelActionTests {

    @Test("initial state has isDiscovering false and empty services")
    func initialState() {
        let vm = BonjourDiscoveryToolViewModel(bonjourService: MockBonjourDiscoveryServiceForTests())
        #expect(vm.isDiscovering == false)
        #expect(vm.services.isEmpty)
        #expect(vm.hasDiscoveredOnce == false)
    }

    @Test("startDiscovery sets isDiscovering to true")
    func startDiscoverySetsIsDiscovering() {
        let mock = MockBonjourDiscoveryServiceForTests()
        let vm = BonjourDiscoveryToolViewModel(bonjourService: mock)

        vm.startDiscovery()

        #expect(vm.isDiscovering == true)
        #expect(mock.startDiscoveryCalled == true)
        vm.stopDiscovery()
    }

    @Test("stopDiscovery sets isDiscovering to false")
    func stopDiscoverySetsIsDiscoveringFalse() {
        let mock = MockBonjourDiscoveryServiceForTests()
        let vm = BonjourDiscoveryToolViewModel(bonjourService: mock)

        vm.startDiscovery()
        vm.stopDiscovery()

        #expect(vm.isDiscovering == false)
        #expect(mock.stopDiscoveryCalled == true)
    }

    @Test("groupedServices groups services by serviceCategory")
    func groupedServicesGroupsByCategory() {
        let vm = BonjourDiscoveryToolViewModel(bonjourService: MockBonjourDiscoveryServiceForTests())
        vm.services = [
            BonjourService(name: "Website", type: "_http._tcp"),
            BonjourService(name: "SecureSite", type: "_https._tcp"),
            BonjourService(name: "My Mac SSH", type: "_ssh._tcp"),
            BonjourService(name: "Office Printer", type: "_printer._tcp")
        ]

        let groups = vm.groupedServices
        #expect(groups["Web"]?.count == 2)
        #expect(groups["Remote Access"]?.count == 1)
        #expect(groups["Printing"]?.count == 1)
    }
}

// MARK: - DashboardViewModel Action Tests

@Suite("DashboardViewModel Action Tests")
@MainActor
struct DashboardViewModelActionTests {

    @Test("startDeviceScan delegates to device discovery service")
    func startDeviceScanDelegates() async {
        let mockDiscovery = MockTrackingDeviceDiscovery()
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: MockPublicIPServiceForVM(),
            deviceDiscoveryService: mockDiscovery,
            macConnectionService: MockMacConnectionServiceForVM()
        )

        await vm.startDeviceScan()

        let callCount = await mockDiscovery.scanCounter.count
        #expect(callCount == 1)
    }

    @Test("refreshPublicIP calls fetchPublicIP with forceRefresh true")
    func refreshPublicIPPassesForceRefresh() async {
        let mockPublicIP = MockTrackingPublicIPService()
        let vm = DashboardViewModel(
            networkMonitor: MockNetworkMonitorServiceForVM(),
            wifiService: MockWiFiInfoServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            publicIPService: mockPublicIP,
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        await vm.refreshPublicIP()

        #expect(mockPublicIP.lastForceRefresh == true)
    }
}

// MARK: - NetworkMapViewModel Tests

@Suite("NetworkMapViewModel Tests")
@MainActor
struct NetworkMapViewModelActionTests {

    @Test("selectDevice sets selectedDeviceIP")
    func selectDeviceSetsIP() {
        let vm = NetworkMapViewModel(
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            bonjourService: MockBonjourDiscoveryServiceForTests(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        vm.selectDevice("192.168.1.10")

        #expect(vm.selectedDeviceIP == "192.168.1.10")
    }

    @Test("selectDevice with same IP deselects (toggles to nil)")
    func selectDeviceTogglesToNil() {
        let vm = NetworkMapViewModel(
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            bonjourService: MockBonjourDiscoveryServiceForTests(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        vm.selectDevice("192.168.1.10")
        #expect(vm.selectedDeviceIP == "192.168.1.10")

        vm.selectDevice("192.168.1.10")
        #expect(vm.selectedDeviceIP == nil)
    }

    @Test("selectDevice with different IP updates selection")
    func selectDeviceUpdatesToDifferentIP() {
        let vm = NetworkMapViewModel(
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockGatewayServiceForVM(),
            bonjourService: MockBonjourDiscoveryServiceForTests(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        vm.selectDevice("192.168.1.10")
        vm.selectDevice("192.168.1.20")

        #expect(vm.selectedDeviceIP == "192.168.1.20")
    }

    @Test("startScan delegates to device discovery when no cached devices")
    func startScanDelegatesToDiscovery() async {
        let mockDiscovery = MockTrackingDeviceDiscovery()
        let vm = NetworkMapViewModel(
            deviceDiscoveryService: mockDiscovery,
            gatewayService: MockGatewayServiceForVM(),
            bonjourService: MockBonjourDiscoveryServiceForTests(),
            macConnectionService: MockMacConnectionServiceForVM()
        )

        await vm.startScan()

        let callCount = await mockDiscovery.scanCounter.count
        #expect(callCount == 1)
    }
}

// MARK: - ToolsViewModel Action Tests

@Suite("ToolsViewModel Action Tests")
@MainActor
struct ToolsViewModelActionTests {

    @Test("pingGateway updates lastGatewayResult when gateway is found")
    func pingGatewayUpdatesResult() async {
        let vm = ToolsViewModel(
            pingService: MockPingServiceForVM(),
            portScannerService: MockPortScannerServiceForVM(),
            dnsLookupService: MockDNSLookupServiceForVM(),
            wakeOnLANService: MockWakeOnLANServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockGatewayServiceForVM()
        )

        await vm.pingGateway()

        #expect(vm.lastGatewayResult != nil)
        #expect(vm.lastGatewayResult?.contains("192.168.1.1") == true)
    }

    @Test("pingGateway sets no gateway message when no gateway detected")
    func pingGatewayNoGatewayFound() async {
        let vm = ToolsViewModel(
            pingService: MockPingServiceForVM(),
            portScannerService: MockPortScannerServiceForVM(),
            dnsLookupService: MockDNSLookupServiceForVM(),
            wakeOnLANService: MockWakeOnLANServiceForVM(),
            deviceDiscoveryService: MockDeviceDiscoveryServiceForVM(),
            gatewayService: MockNoGatewayService()
        )

        await vm.pingGateway()

        #expect(vm.lastGatewayResult == "No gateway found")
    }
}
