import Foundation

// MARK: - Service Protocols for Dependency Injection

/// Protocol for ping operations
protocol PingServiceProtocol: AnyObject, Sendable {
    func ping(host: String, count: Int, timeout: TimeInterval) async -> AsyncStream<PingResult>
    func stop() async
    func calculateStatistics(_ results: [PingResult], requestedCount: Int?) async -> PingStatistics?
}

/// Protocol for port scanning operations
protocol PortScannerServiceProtocol: AnyObject, Sendable {
    func scan(host: String, ports: [Int], timeout: TimeInterval) async -> AsyncStream<PortScanResult>
    func stop() async
}

/// Protocol for DNS lookup operations
@MainActor
protocol DNSLookupServiceProtocol {
    var isLoading: Bool { get }
    var lastError: String? { get }
    func lookup(domain: String, recordType: DNSRecordType, server: String?) async -> DNSQueryResult?
}

/// Protocol for WHOIS lookup operations
protocol WHOISServiceProtocol: AnyObject, Sendable {
    func lookup(query: String) async throws -> WHOISResult
}

/// Protocol for Wake on LAN operations
@MainActor
protocol WakeOnLANServiceProtocol {
    var isSending: Bool { get }
    var lastResult: WakeOnLANResult? { get }
    var lastError: String? { get }
    func wake(macAddress: String, broadcastAddress: String, port: UInt16) async -> Bool
}

/// Protocol for speed test operations
@MainActor
protocol SpeedTestServiceProtocol {
    var downloadSpeed: Double { get }
    var uploadSpeed: Double { get }
    var latency: Double { get }
    var progress: Double { get }
    var phase: SpeedTestService.Phase { get }
    var isRunning: Bool { get }
    var errorMessage: String? { get }
    func startTest() async throws -> SpeedTestData
    func stopTest()
}

/// Protocol for network monitoring
@MainActor
protocol NetworkMonitorServiceProtocol {
    var isConnected: Bool { get }
    var connectionType: ConnectionType { get }
    var isExpensive: Bool { get }
    var isConstrained: Bool { get }
    var statusText: String { get }
    func startMonitoring()
    func stopMonitoring()
}

/// Protocol for device discovery
@MainActor
protocol DeviceDiscoveryServiceProtocol {
    var discoveredDevices: [DiscoveredDevice] { get }
    var isScanning: Bool { get }
    var scanProgress: Double { get }
    var lastScanDate: Date? { get }
    func scanNetwork(subnet: String?) async
    func stopScan()
}

/// Protocol for gateway detection
@MainActor
protocol GatewayServiceProtocol {
    var gateway: GatewayInfo? { get }
    var isLoading: Bool { get }
    func detectGateway() async
}

/// Protocol for public IP lookup
@MainActor
protocol PublicIPServiceProtocol {
    var ispInfo: ISPInfo? { get }
    var isLoading: Bool { get }
    func fetchPublicIP(forceRefresh: Bool) async
}

/// Protocol for WiFi info
@MainActor
protocol WiFiInfoServiceProtocol {
    var currentWiFi: WiFiInfo? { get }
    var isLocationAuthorized: Bool { get }
    func requestLocationPermission()
    func refreshWiFiInfo()
}

/// Protocol for Bonjour discovery
@MainActor
protocol BonjourDiscoveryServiceProtocol {
    var discoveredServices: [BonjourService] { get }
    var isDiscovering: Bool { get }
    func discoveryStream(serviceType: String?) -> AsyncStream<BonjourService>
    func startDiscovery(serviceType: String?)
    func stopDiscovery()
    func resolveService(_ service: BonjourService) async -> BonjourService?
}

/// Protocol for traceroute operations
protocol TracerouteServiceProtocol: AnyObject, Sendable {
    func trace(host: String, maxHops: Int?, timeout: TimeInterval?) async -> AsyncStream<TracerouteHop>
    func stop() async
}

// MARK: - Conformances

extension PingService: PingServiceProtocol {}
extension PortScannerService: PortScannerServiceProtocol {}
extension DNSLookupService: DNSLookupServiceProtocol {}
extension WHOISService: WHOISServiceProtocol {}
extension WakeOnLANService: WakeOnLANServiceProtocol {}
extension SpeedTestService: SpeedTestServiceProtocol {}
extension NetworkMonitorService: NetworkMonitorServiceProtocol {}
extension DeviceDiscoveryService: DeviceDiscoveryServiceProtocol {}
extension GatewayService: GatewayServiceProtocol {}
extension PublicIPService: PublicIPServiceProtocol {}
extension WiFiInfoService: WiFiInfoServiceProtocol {}
extension BonjourDiscoveryService: BonjourDiscoveryServiceProtocol {}
extension TracerouteService: TracerouteServiceProtocol {}
