import Foundation
import SwiftData

@Model
final class PairedMac {
    @Attribute(.unique) var id: UUID
    var name: String
    var hostname: String?
    var ipAddress: String?
    var port: Int
    var lastConnected: Date?
    var isPrimary: Bool
    var isConnected: Bool
    var pairingCode: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        hostname: String? = nil,
        ipAddress: String? = nil,
        port: Int = 8849,
        lastConnected: Date? = nil,
        isPrimary: Bool = false,
        isConnected: Bool = false,
        pairingCode: String? = nil
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.ipAddress = ipAddress
        self.port = port
        self.lastConnected = lastConnected
        self.isPrimary = isPrimary
        self.isConnected = isConnected
        self.pairingCode = pairingCode
        self.createdAt = Date()
    }
    
    var displayAddress: String {
        if let ip = ipAddress {
            return "\(ip):\(port)"
        } else if let host = hostname {
            return "\(host):\(port)"
        }
        return "Not configured"
    }
    
    var connectionStatusText: String {
        if isConnected {
            return "Connected"
        } else if lastConnected != nil {
            return "Disconnected"
        }
        return "Never connected"
    }
}
