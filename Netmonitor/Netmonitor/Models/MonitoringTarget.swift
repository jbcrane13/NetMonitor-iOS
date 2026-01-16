import Foundation
import SwiftData

@Model
final class MonitoringTarget {
    @Attribute(.unique) var id: UUID
    var name: String
    var host: String
    var port: Int?
    var targetProtocol: TargetProtocol
    var isEnabled: Bool
    var checkInterval: TimeInterval
    var timeout: TimeInterval
    var currentLatency: Double?
    var averageLatency: Double?
    var minLatency: Double?
    var maxLatency: Double?
    var isOnline: Bool
    var consecutiveFailures: Int
    var totalChecks: Int
    var successfulChecks: Int
    var lastChecked: Date?
    var lastStatusChange: Date?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int? = nil,
        targetProtocol: TargetProtocol = .icmp,
        isEnabled: Bool = true,
        checkInterval: TimeInterval = 60,
        timeout: TimeInterval = 5
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.targetProtocol = targetProtocol
        self.isEnabled = isEnabled
        self.checkInterval = checkInterval
        self.timeout = timeout
        self.isOnline = false
        self.consecutiveFailures = 0
        self.totalChecks = 0
        self.successfulChecks = 0
        self.createdAt = Date()
    }
    
    var statusType: StatusType {
        isOnline ? .online : .offline
    }
    
    var uptimePercentage: Double {
        guard totalChecks > 0 else { return 0 }
        return Double(successfulChecks) / Double(totalChecks) * 100
    }
    
    var uptimeText: String {
        String(format: "%.1f%%", uptimePercentage)
    }
    
    var latencyText: String? {
        guard let latency = currentLatency else { return nil }
        if latency < 1 {
            return "<1 ms"
        }
        return String(format: "%.0f ms", latency)
    }
    
    var hostWithPort: String {
        if let port = port {
            return "\(host):\(port)"
        }
        return host
    }
    
    func recordSuccess(latency: Double) {
        let wasOffline = !isOnline
        
        totalChecks += 1
        successfulChecks += 1
        consecutiveFailures = 0
        currentLatency = latency
        isOnline = true
        lastChecked = Date()
        
        if wasOffline {
            lastStatusChange = Date()
        }
        
        updateLatencyStats(latency)
    }
    
    func recordFailure() {
        let wasOnline = isOnline
        
        totalChecks += 1
        consecutiveFailures += 1
        currentLatency = nil
        lastChecked = Date()
        
        if consecutiveFailures >= 3 {
            isOnline = false
            if wasOnline {
                lastStatusChange = Date()
            }
        }
    }
    
    private func updateLatencyStats(_ latency: Double) {
        if let current = averageLatency {
            let weight = min(Double(successfulChecks), 100.0)
            averageLatency = (current * (weight - 1) + latency) / weight
        } else {
            averageLatency = latency
        }
        
        if let min = minLatency {
            minLatency = Swift.min(min, latency)
        } else {
            minLatency = latency
        }
        
        if let max = maxLatency {
            maxLatency = Swift.max(max, latency)
        } else {
            maxLatency = latency
        }
    }
}
