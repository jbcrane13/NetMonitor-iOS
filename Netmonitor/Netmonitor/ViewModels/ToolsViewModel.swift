import Foundation
import SwiftData

@MainActor
@Observable
final class ToolsViewModel {
    private(set) var recentResults: [ToolActivityItem] = []
    private(set) var isPingRunning = false
    private(set) var isPortScanRunning = false
    private(set) var currentPingResults: [PingResult] = []
    private(set) var currentPortScanResults: [PortScanResult] = []
    
    let pingService: PingService
    let portScannerService: PortScannerService
    let dnsLookupService: DNSLookupService
    let wakeOnLANService: WakeOnLANService
    let deviceDiscoveryService: DeviceDiscoveryService
    let gatewayService: GatewayService
    
    init(
        pingService: PingService = .init(),
        portScannerService: PortScannerService = .init(),
        dnsLookupService: DNSLookupService = .init(),
        wakeOnLANService: WakeOnLANService = .init(),
        deviceDiscoveryService: DeviceDiscoveryService = .init(),
        gatewayService: GatewayService = .init()
    ) {
        self.pingService = pingService
        self.portScannerService = portScannerService
        self.dnsLookupService = dnsLookupService
        self.wakeOnLANService = wakeOnLANService
        self.deviceDiscoveryService = deviceDiscoveryService
        self.gatewayService = gatewayService
    }
    
    var isScanning: Bool {
        deviceDiscoveryService.isScanning
    }
    
    func runPing(host: String, count: Int = 4) async {
        guard !isPingRunning else { return }
        isPingRunning = true
        currentPingResults = []
        
        defer { isPingRunning = false }
        
        let stream = await pingService.ping(host: host, count: count)
        
        for await result in stream {
            currentPingResults.append(result)
        }
        
        if let stats = await pingService.calculateStatistics(currentPingResults) {
            addActivity(
                tool: "Ping",
                target: host,
                result: "\(String(format: "%.0f", stats.avgTime)) ms avg",
                success: stats.received > 0
            )
        }
    }
    
    func stopPing() async {
        await pingService.stop()
    }
    
    func runPortScan(host: String, ports: [Int]) async {
        guard !isPortScanRunning else { return }
        isPortScanRunning = true
        currentPortScanResults = []
        
        defer { isPortScanRunning = false }
        
        let stream = await portScannerService.scan(host: host, ports: ports)
        
        for await result in stream {
            if result.state == .open {
                currentPortScanResults.append(result)
            }
        }
        
        let openCount = currentPortScanResults.count
        addActivity(
            tool: "Port Scan",
            target: host,
            result: "\(openCount) ports open",
            success: true
        )
    }
    
    func stopPortScan() async {
        await portScannerService.stop()
    }
    
    func runDNSLookup(domain: String) async -> DNSQueryResult? {
        let result = await dnsLookupService.lookup(domain: domain)
        
        if let result = result {
            addActivity(
                tool: "DNS Lookup",
                target: domain,
                result: "\(result.records.count) records",
                success: true
            )
        } else {
            addActivity(
                tool: "DNS Lookup",
                target: domain,
                result: "Failed",
                success: false
            )
        }
        
        return result
    }
    
    func sendWakeOnLAN(macAddress: String) async -> Bool {
        let success = await wakeOnLANService.wake(macAddress: macAddress)
        
        addActivity(
            tool: "Wake on LAN",
            target: macAddress,
            result: success ? "Sent" : "Failed",
            success: success
        )
        
        return success
    }
    
    func runNetworkScan() async {
        await deviceDiscoveryService.scanNetwork()
        
        addActivity(
            tool: "Network Scan",
            target: "Local Network",
            result: "\(deviceDiscoveryService.discoveredDevices.count) devices",
            success: true
        )
    }
    
    func pingGateway() async {
        await gatewayService.detectGateway()
        
        if let gateway = gatewayService.gateway {
            addActivity(
                tool: "Ping",
                target: gateway.ipAddress,
                result: gateway.latencyText ?? "Connected",
                success: true
            )
        }
    }
    
    func clearActivity() {
        recentResults = []
    }
    
    private func addActivity(tool: String, target: String, result: String, success: Bool) {
        let item = ToolActivityItem(
            tool: tool,
            target: target,
            result: result,
            success: success,
            timestamp: Date()
        )
        recentResults.insert(item, at: 0)
        
        if recentResults.count > 20 {
            recentResults = Array(recentResults.prefix(20))
        }
    }
}

struct ToolActivityItem: Identifiable {
    let id = UUID()
    let tool: String
    let target: String
    let result: String
    let success: Bool
    let timestamp: Date
    
    var timeAgoText: String {
        let interval = Date().timeIntervalSince(timestamp)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}
