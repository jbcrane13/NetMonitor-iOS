import Foundation
import SwiftUI

struct NetworkStatus: Sendable {
    let connectionType: ConnectionType
    let isConnected: Bool
    let isExpensive: Bool
    let isConstrained: Bool
    let wifi: WiFiInfo?
    let gateway: GatewayInfo?
    let publicIP: ISPInfo?
    let updatedAt: Date
    
    init(
        connectionType: ConnectionType = .none,
        isConnected: Bool = false,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        wifi: WiFiInfo? = nil,
        gateway: GatewayInfo? = nil,
        publicIP: ISPInfo? = nil
    ) {
        self.connectionType = connectionType
        self.isConnected = isConnected
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.wifi = wifi
        self.gateway = gateway
        self.publicIP = publicIP
        self.updatedAt = Date()
    }
    
    static let disconnected = NetworkStatus()
}

struct WiFiInfo: Sendable, Equatable {
    let ssid: String
    let bssid: String?
    let signalStrength: Int?
    let signalDBm: Int?
    let channel: Int?
    let frequency: String?
    let band: WiFiBand?
    let securityType: String?
    let noiseLevel: Int?
    
    init(
        ssid: String,
        bssid: String? = nil,
        signalStrength: Int? = nil,
        signalDBm: Int? = nil,
        channel: Int? = nil,
        frequency: String? = nil,
        band: WiFiBand? = nil,
        securityType: String? = nil,
        noiseLevel: Int? = nil
    ) {
        self.ssid = ssid
        self.bssid = bssid
        self.signalStrength = signalStrength
        self.signalDBm = signalDBm
        self.channel = channel
        self.frequency = frequency
        self.band = band
        self.securityType = securityType
        self.noiseLevel = noiseLevel
    }
    
    var signalQuality: SignalQuality {
        guard let dbm = signalDBm else { return .unknown }
        switch dbm {
        case -50...0: return .excellent
        case -60 ..< -50: return .good
        case -70 ..< -60: return .fair
        default: return .poor
        }
    }
    
    var signalBars: Int {
        guard let dbm = signalDBm else { return 0 }
        switch dbm {
        case -50...0: return 4
        case -60 ..< -50: return 3
        case -70 ..< -60: return 2
        case -80 ..< -70: return 1
        default: return 0
        }
    }
}

enum WiFiBand: String, Sendable {
    case band2_4GHz = "2.4 GHz"
    case band5GHz = "5 GHz"
    case band6GHz = "6 GHz"
}

enum SignalQuality: String, Sendable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case unknown = "Unknown"
    
    var color: SwiftUI.Color {
        switch self {
        case .excellent: Theme.Colors.success
        case .good: Theme.Colors.success
        case .fair: Theme.Colors.warning
        case .poor: Theme.Colors.error
        case .unknown: Theme.Colors.textSecondary
        }
    }
}

struct GatewayInfo: Sendable, Equatable {
    let ipAddress: String
    let macAddress: String?
    let vendor: String?
    let latency: Double?
    
    init(
        ipAddress: String,
        macAddress: String? = nil,
        vendor: String? = nil,
        latency: Double? = nil
    ) {
        self.ipAddress = ipAddress
        self.macAddress = macAddress
        self.vendor = vendor
        self.latency = latency
    }
    
    var latencyText: String? {
        guard let latency = latency else { return nil }
        if latency < 1 {
            return "<1 ms"
        }
        return String(format: "%.0f ms", latency)
    }
}

struct ISPInfo: Sendable, Equatable {
    let publicIP: String
    let ispName: String?
    let asn: String?
    let organization: String?
    let city: String?
    let region: String?
    let country: String?
    let countryCode: String?
    let timezone: String?
    let fetchedAt: Date
    
    init(
        publicIP: String,
        ispName: String? = nil,
        asn: String? = nil,
        organization: String? = nil,
        city: String? = nil,
        region: String? = nil,
        country: String? = nil,
        countryCode: String? = nil,
        timezone: String? = nil
    ) {
        self.publicIP = publicIP
        self.ispName = ispName
        self.asn = asn
        self.organization = organization
        self.city = city
        self.region = region
        self.country = country
        self.countryCode = countryCode
        self.timezone = timezone
        self.fetchedAt = Date()
    }
    
    var locationText: String? {
        var parts: [String] = []
        if let city = city { parts.append(city) }
        if let country = countryCode ?? country { parts.append(country) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
