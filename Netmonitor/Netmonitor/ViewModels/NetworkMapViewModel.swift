import Foundation

@MainActor
@Observable
final class NetworkMapViewModel {
    var selectedDeviceIP: String?
    
    let deviceDiscoveryService: any DeviceDiscoveryServiceProtocol
    let gatewayService: any GatewayServiceProtocol
    let bonjourService: any BonjourDiscoveryServiceProtocol
    
    init(
        deviceDiscoveryService: any DeviceDiscoveryServiceProtocol = DeviceDiscoveryService(),
        gatewayService: any GatewayServiceProtocol = GatewayService(),
        bonjourService: any BonjourDiscoveryServiceProtocol = BonjourDiscoveryService()
    ) {
        self.deviceDiscoveryService = deviceDiscoveryService
        self.gatewayService = gatewayService
        self.bonjourService = bonjourService
    }
    
    var discoveredDevices: [DiscoveredDevice] {
        deviceDiscoveryService.discoveredDevices
    }
    
    var isScanning: Bool {
        deviceDiscoveryService.isScanning
    }
    
    var scanProgress: Double {
        deviceDiscoveryService.scanProgress
    }
    
    var deviceCount: Int {
        discoveredDevices.count
    }
    
    var gateway: GatewayInfo? {
        gatewayService.gateway
    }
    
    var bonjourServices: [BonjourService] {
        bonjourService.discoveredServices
    }
    
    func startScan(forceRefresh: Bool = false) async {
        // Skip if we already have results from a recent scan (within 60 seconds)
        if !forceRefresh,
           !discoveredDevices.isEmpty,
           let lastScan = deviceDiscoveryService.lastScanDate,
           Date().timeIntervalSince(lastScan) < 60 {
            return
        }
        await deviceDiscoveryService.scanNetwork(subnet: nil)
    }
    
    func stopScan() {
        deviceDiscoveryService.stopScan()
    }
    
    func selectDevice(_ ip: String?) {
        selectedDeviceIP = selectedDeviceIP == ip ? nil : ip
    }
    
    func startBonjourDiscovery() {
        bonjourService.startDiscovery(serviceType: nil)
    }
    
    func stopBonjourDiscovery() {
        bonjourService.stopDiscovery()
    }
    
    func refresh() async {
        await gatewayService.detectGateway()
        await startScan(forceRefresh: true)
    }
}
