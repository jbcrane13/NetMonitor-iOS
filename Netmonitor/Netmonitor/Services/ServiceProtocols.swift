import Foundation
import NetworkScanKit

// MARK: - Top-Level Enums (decoupled from concrete service types)

/// Speed test execution phases (extracted from SpeedTestService for protocol decoupling)
enum SpeedTestPhase: String, Sendable {
    case idle
    case latency
    case download
    case upload
    case complete
}

/// Device discovery scan display phases (extracted from DeviceDiscoveryService for protocol decoupling)
enum ScanDisplayPhase: String, Sendable {
    case idle = ""
    case arpScan = "Scanning network…"
    case tcpProbe = "Probing ports…"
    case bonjour = "Bonjour discovery…"
    case ssdp = "UPnP discovery…"
    case companion = "Mac companion…"
    case resolving = "Resolving names…"
    case done = "Complete"
}

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
protocol DNSLookupServiceProtocol: AnyObject {
    @MainActor var isLoading: Bool { get }
    @MainActor var lastError: String? { get }
    @MainActor func lookup(domain: String, recordType: DNSRecordType, server: String?) async -> DNSQueryResult?
}

/// Protocol for WHOIS lookup operations
protocol WHOISServiceProtocol: AnyObject, Sendable {
    func lookup(query: String) async throws -> WHOISResult
}

/// Protocol for Wake on LAN operations
protocol WakeOnLANServiceProtocol {
    @MainActor var isSending: Bool { get }
    @MainActor var lastResult: WakeOnLANResult? { get }
    @MainActor var lastError: String? { get }
    @MainActor func wake(macAddress: String, broadcastAddress: String, port: UInt16) async -> Bool
}

/// Protocol for speed test operations
protocol SpeedTestServiceProtocol {
    @MainActor var downloadSpeed: Double { get }
    @MainActor var uploadSpeed: Double { get }
    @MainActor var latency: Double { get }
    @MainActor var progress: Double { get }
    @MainActor var phase: SpeedTestPhase { get }
    @MainActor var isRunning: Bool { get }
    @MainActor var errorMessage: String? { get }
    @MainActor var duration: TimeInterval { get set }
    @MainActor func startTest() async throws -> SpeedTestData
    @MainActor func stopTest()
}

/// Protocol for network monitoring
protocol NetworkMonitorServiceProtocol {
    @MainActor var isConnected: Bool { get }
    @MainActor var connectionType: ConnectionType { get }
    @MainActor var isExpensive: Bool { get }
    @MainActor var isConstrained: Bool { get }
    @MainActor var statusText: String { get }
    @MainActor func startMonitoring()
    @MainActor func stopMonitoring()
}

/// Protocol for device discovery
protocol DeviceDiscoveryServiceProtocol: AnyObject, Sendable {
    @MainActor var discoveredDevices: [DiscoveredDevice] { get }
    @MainActor var isScanning: Bool { get }
    @MainActor var scanProgress: Double { get }
    @MainActor var scanPhase: ScanDisplayPhase { get }
    @MainActor var lastScanDate: Date? { get }
    func scanNetwork(subnet: String?) async
    @MainActor func stopScan()
}

/// Protocol for gateway detection
protocol GatewayServiceProtocol {
    @MainActor var gateway: GatewayInfo? { get }
    @MainActor var isLoading: Bool { get }
    @MainActor func detectGateway() async
}

/// Protocol for public IP lookup
protocol PublicIPServiceProtocol {
    @MainActor var ispInfo: ISPInfo? { get }
    @MainActor var isLoading: Bool { get }
    @MainActor func fetchPublicIP(forceRefresh: Bool) async
}

/// Protocol for WiFi info
protocol WiFiInfoServiceProtocol {
    @MainActor var currentWiFi: WiFiInfo? { get }
    @MainActor var isLocationAuthorized: Bool { get }
    @MainActor func requestLocationPermission()
    @MainActor func refreshWiFiInfo()
}

/// Protocol for Bonjour discovery
protocol BonjourDiscoveryServiceProtocol: AnyObject, Sendable {
    @MainActor var discoveredServices: [BonjourService] { get }
    @MainActor var isDiscovering: Bool { get }
    @MainActor func discoveryStream(serviceType: String?) -> AsyncStream<BonjourService>
    @MainActor func startDiscovery(serviceType: String?)
    @MainActor func stopDiscovery()
    func resolveService(_ service: BonjourService) async -> BonjourService?
}

/// Protocol for traceroute operations
protocol TracerouteServiceProtocol: AnyObject, Sendable {
    func trace(host: String, maxHops: Int?, timeout: TimeInterval?) async -> AsyncStream<TracerouteHop>
    func stop() async
}

/// Protocol for MAC vendor lookup
protocol MACVendorLookupServiceProtocol: AnyObject, Sendable {
    func lookup(macAddress: String) async -> String?
}

/// Protocol for device name resolution
protocol DeviceNameResolverProtocol: Sendable {
    func resolve(ipAddress: String) async -> String?
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
extension MACVendorLookupService: MACVendorLookupServiceProtocol {}
extension DeviceNameResolver: DeviceNameResolverProtocol {}
// MacConnectionService declares conformance at its class definition
