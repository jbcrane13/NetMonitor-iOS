import Foundation

@MainActor
@Observable
final class NetworkMapViewModel {
    private(set) var selectedDeviceIP: String?
    
    let deviceDiscoveryService: DeviceDiscoveryService
    let gatewayService: GatewayService
    let bonjourService: BonjourDiscoveryService
    
    init(
        deviceDiscoveryService: DeviceDiscoveryService = .init(),
        gatewayService: GatewayService = .init(),
        bonjourService: BonjourDiscoveryService = .init()
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
    
    func startScan() async {
        await deviceDiscoveryService.scanNetwork()
    }
    
    func stopScan() {
        deviceDiscoveryService.stopScan()
    }
    
    func selectDevice(_ ip: String?) {
        selectedDeviceIP = selectedDeviceIP == ip ? nil : ip
    }
    
    func startBonjourDiscovery() {
        bonjourService.startDiscovery()
    }
    
    func stopBonjourDiscovery() {
        bonjourService.stopDiscovery()
    }
    
    func refresh() async {
        async let gatewayTask: () = gatewayService.detectGateway()
        async let scanTask: () = deviceDiscoveryService.scanNetwork()
        
        await gatewayTask
        await scanTask
    }
}
