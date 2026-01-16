import Foundation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    private(set) var isRefreshing = false
    private(set) var sessionStartTime: Date
    
    let networkMonitor: NetworkMonitorService
    let wifiService: WiFiInfoService
    let gatewayService: GatewayService
    let publicIPService: PublicIPService
    let deviceDiscoveryService: DeviceDiscoveryService
    
    init(
        networkMonitor: NetworkMonitorService = .init(),
        wifiService: WiFiInfoService = .init(),
        gatewayService: GatewayService = .init(),
        publicIPService: PublicIPService = .init(),
        deviceDiscoveryService: DeviceDiscoveryService = .init()
    ) {
        self.networkMonitor = networkMonitor
        self.wifiService = wifiService
        self.gatewayService = gatewayService
        self.publicIPService = publicIPService
        self.deviceDiscoveryService = deviceDiscoveryService
        self.sessionStartTime = Date()
    }
    
    var isConnected: Bool {
        networkMonitor.isConnected
    }
    
    var connectionType: ConnectionType {
        networkMonitor.connectionType
    }
    
    var connectionStatusText: String {
        networkMonitor.statusText
    }
    
    var currentWiFi: WiFiInfo? {
        wifiService.currentWiFi
    }
    
    var gateway: GatewayInfo? {
        gatewayService.gateway
    }
    
    var ispInfo: ISPInfo? {
        publicIPService.ispInfo
    }
    
    var discoveredDevices: [DiscoveredDevice] {
        deviceDiscoveryService.discoveredDevices
    }
    
    var deviceCount: Int {
        discoveredDevices.count
    }
    
    var lastScanDate: Date? {
        deviceDiscoveryService.lastScanDate
    }
    
    var isScanning: Bool {
        deviceDiscoveryService.isScanning
    }
    
    var sessionDuration: String {
        let interval = Date().timeIntervalSince(sessionStartTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var sessionStartTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Today, \(formatter.string(from: sessionStartTime))"
    }
    
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        
        wifiService.refreshWiFiInfo()
        
        async let gatewayTask: () = gatewayService.detectGateway()
        async let publicIPTask: () = publicIPService.fetchPublicIP(forceRefresh: true)
        
        await gatewayTask
        await publicIPTask
    }
    
    func startDeviceScan() async {
        await deviceDiscoveryService.scanNetwork()
    }
    
    func stopDeviceScan() {
        deviceDiscoveryService.stopScan()
    }
    
    func refreshPublicIP() async {
        await publicIPService.fetchPublicIP(forceRefresh: true)
    }
    
    func requestLocationPermission() {
        wifiService.requestLocationPermission()
    }
    
    var needsLocationPermission: Bool {
        !wifiService.isLocationAuthorized
    }
}
