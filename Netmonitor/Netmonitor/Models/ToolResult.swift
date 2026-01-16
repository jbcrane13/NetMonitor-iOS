import Foundation
import SwiftData

@Model
final class ToolResult {
    @Attribute(.unique) var id: UUID
    var toolType: ToolType
    var target: String
    var timestamp: Date
    var duration: TimeInterval
    var success: Bool
    var summary: String
    var details: String
    var errorMessage: String?
    
    init(
        id: UUID = UUID(),
        toolType: ToolType,
        target: String,
        duration: TimeInterval = 0,
        success: Bool,
        summary: String,
        details: String = "",
        errorMessage: String? = nil
    ) {
        self.id = id
        self.toolType = toolType
        self.target = target
        self.timestamp = Date()
        self.duration = duration
        self.success = success
        self.summary = summary
        self.details = details
        self.errorMessage = errorMessage
    }
    
    var formattedDuration: String {
        if duration < 1 {
            return String(format: "%.0f ms", duration * 1000)
        }
        return String(format: "%.2f s", duration)
    }
    
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

@Model
final class SpeedTestResult {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var downloadSpeed: Double
    var uploadSpeed: Double
    var latency: Double
    var jitter: Double?
    var serverName: String?
    var serverLocation: String?
    var connectionType: ConnectionType
    var success: Bool
    var errorMessage: String?
    
    init(
        id: UUID = UUID(),
        downloadSpeed: Double,
        uploadSpeed: Double,
        latency: Double,
        jitter: Double? = nil,
        serverName: String? = nil,
        serverLocation: String? = nil,
        connectionType: ConnectionType = .wifi,
        success: Bool = true,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.timestamp = Date()
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.latency = latency
        self.jitter = jitter
        self.serverName = serverName
        self.serverLocation = serverLocation
        self.connectionType = connectionType
        self.success = success
        self.errorMessage = errorMessage
    }
    
    var downloadSpeedText: String {
        formatSpeed(downloadSpeed)
    }
    
    var uploadSpeedText: String {
        formatSpeed(uploadSpeed)
    }
    
    var latencyText: String {
        String(format: "%.0f ms", latency)
    }
    
    private func formatSpeed(_ speedMbps: Double) -> String {
        if speedMbps >= 1000 {
            return String(format: "%.1f Gbps", speedMbps / 1000)
        }
        return String(format: "%.1f Mbps", speedMbps)
    }
}
