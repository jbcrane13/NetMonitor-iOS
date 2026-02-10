import Foundation
import SwiftData

@Model
final class LocalDevice {
    @Attribute(.unique) var id: UUID
    var ipAddress: String
    var macAddress: String
    var hostname: String?
    var vendor: String?
    var deviceType: DeviceType
    var customName: String?
    var status: DeviceStatus
    var lastLatency: Double?
    var isGateway: Bool
    var supportsWakeOnLan: Bool
    var firstSeen: Date
    var lastSeen: Date
    var notes: String?
    var resolvedHostname: String?
    var manufacturer: String?
    var openPorts: [Int]?
    var discoveredServices: [String]?

    init(
        id: UUID = UUID(),
        ipAddress: String,
        macAddress: String,
        hostname: String? = nil,
        vendor: String? = nil,
        deviceType: DeviceType = .unknown,
        customName: String? = nil,
        status: DeviceStatus = .online,
        lastLatency: Double? = nil,
        isGateway: Bool = false,
        supportsWakeOnLan: Bool = false,
        notes: String? = nil,
        resolvedHostname: String? = nil,
        manufacturer: String? = nil,
        openPorts: [Int]? = nil,
        discoveredServices: [String]? = nil
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.hostname = hostname
        self.vendor = vendor
        self.deviceType = deviceType
        self.customName = customName
        self.status = status
        self.lastLatency = lastLatency
        self.isGateway = isGateway
        self.supportsWakeOnLan = supportsWakeOnLan
        self.firstSeen = Date()
        self.lastSeen = Date()
        self.notes = notes
        self.resolvedHostname = resolvedHostname
        self.manufacturer = manufacturer
        self.openPorts = openPorts
        self.discoveredServices = discoveredServices
    }
    
    var displayName: String {
        customName ?? resolvedHostname ?? hostname ?? ipAddress
    }
    
    var formattedMacAddress: String {
        macAddress.uppercased()
    }
    
    var latencyText: String? {
        guard let latency = lastLatency else { return nil }
        if latency < 1 {
            return "<1 ms"
        }
        return String(format: "%.0f ms", latency)
    }
    
    func updateStatus(to newStatus: DeviceStatus) {
        status = newStatus
        lastSeen = Date()
    }
    
    func updateLatency(_ latency: Double) {
        lastLatency = latency
        lastSeen = Date()
        if status == .offline {
            status = .online
        }
    }
}
