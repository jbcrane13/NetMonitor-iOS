import Foundation
import SwiftUI

enum DeviceType: String, Codable, CaseIterable, Sendable {
    case router
    case computer
    case laptop
    case phone
    case tablet
    case tv
    case speaker
    case gaming
    case iot
    case printer
    case camera
    case storage
    case unknown
    
    var iconName: String {
        switch self {
        case .router: "wifi.router"
        case .computer: "desktopcomputer"
        case .laptop: "laptopcomputer"
        case .phone: "iphone"
        case .tablet: "ipad"
        case .tv: "appletv"
        case .speaker: "homepodmini"
        case .gaming: "gamecontroller"
        case .iot: "sensor"
        case .printer: "printer"
        case .camera: "web.camera"
        case .storage: "externaldrive"
        case .unknown: "questionmark.circle"
        }
    }
    
    var displayName: String {
        switch self {
        case .router: "Router"
        case .computer: "Computer"
        case .laptop: "Laptop"
        case .phone: "Phone"
        case .tablet: "Tablet"
        case .tv: "TV"
        case .speaker: "Speaker"
        case .gaming: "Gaming"
        case .iot: "IoT Device"
        case .printer: "Printer"
        case .camera: "Camera"
        case .storage: "Storage"
        case .unknown: "Unknown"
        }
    }
}

enum StatusType: String, CaseIterable, Sendable {
    case online
    case offline
    case idle
    case unknown

    var color: Color {
        switch self {
        case .online: Theme.Colors.online
        case .offline: Theme.Colors.offline
        case .idle: Theme.Colors.idle
        case .unknown: Theme.Colors.textTertiary
        }
    }

    var label: String {
        switch self {
        case .online: "Online"
        case .offline: "Offline"
        case .idle: "Idle"
        case .unknown: "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .online: "checkmark.circle.fill"
        case .offline: "xmark.circle.fill"
        case .idle: "moon.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

enum DeviceStatus: String, Codable, CaseIterable, Sendable {
    case online
    case offline
    case idle
    
    var statusType: StatusType {
        switch self {
        case .online: .online
        case .offline: .offline
        case .idle: .idle
        }
    }
    
    var color: Color {
        statusType.color
    }
}

enum ConnectionType: String, Codable, CaseIterable, Sendable {
    case wifi
    case cellular
    case ethernet
    case none
    
    var iconName: String {
        switch self {
        case .wifi: "wifi"
        case .cellular: "antenna.radiowaves.left.and.right"
        case .ethernet: "cable.connector"
        case .none: "wifi.slash"
        }
    }
    
    var displayName: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .cellular: "Cellular"
        case .ethernet: "Ethernet"
        case .none: "No Connection"
        }
    }
}

enum ToolType: String, Codable, CaseIterable, Sendable {
    case ping
    case traceroute
    case dnsLookup
    case portScan
    case bonjourDiscovery
    case speedTest
    case whois
    case wakeOnLan
    case networkScan
    
    var iconName: String {
        switch self {
        case .ping: "arrow.up.arrow.down"
        case .traceroute: "point.topleft.down.to.point.bottomright.curvepath"
        case .dnsLookup: "globe"
        case .portScan: "door.left.hand.open"
        case .bonjourDiscovery: "bonjour"
        case .speedTest: "speedometer"
        case .whois: "doc.text.magnifyingglass"
        case .wakeOnLan: "power"
        case .networkScan: "network"
        }
    }
    
    var displayName: String {
        switch self {
        case .ping: "Ping"
        case .traceroute: "Traceroute"
        case .dnsLookup: "DNS Lookup"
        case .portScan: "Port Scanner"
        case .bonjourDiscovery: "Bonjour Discovery"
        case .speedTest: "Speed Test"
        case .whois: "WHOIS"
        case .wakeOnLan: "Wake on LAN"
        case .networkScan: "Network Scan"
        }
    }
    
    var color: Color {
        switch self {
        case .ping: Theme.Colors.accent
        case .traceroute: Theme.Colors.info
        case .dnsLookup: Theme.Colors.success
        case .portScan: Theme.Colors.warning
        case .bonjourDiscovery: Theme.Colors.accent
        case .speedTest: Theme.Colors.success
        case .whois: Theme.Colors.info
        case .wakeOnLan: Theme.Colors.error
        case .networkScan: Theme.Colors.accent
        }
    }
}

enum TargetProtocol: String, Codable, CaseIterable, Sendable {
    case icmp
    case tcp
    case http
    case https
    
    var displayName: String {
        switch self {
        case .icmp: "ICMP (Ping)"
        case .tcp: "TCP"
        case .http: "HTTP"
        case .https: "HTTPS"
        }
    }
    
    var defaultPort: Int? {
        switch self {
        case .icmp: nil
        case .tcp: 80
        case .http: 80
        case .https: 443
        }
    }
}

enum DNSRecordType: String, Codable, CaseIterable, Sendable {
    case a = "A"
    case aaaa = "AAAA"
    case mx = "MX"
    case txt = "TXT"
    case cname = "CNAME"
    case ns = "NS"
    case soa = "SOA"
    case ptr = "PTR"
    
    var displayName: String { rawValue }
}

enum PortScanPreset: String, CaseIterable, Sendable {
    case common
    case wellKnown
    case extended
    case web
    case database
    case mail
    case custom

    var displayName: String {
        switch self {
        case .common: "Common Ports"
        case .wellKnown: "Well-Known (1-1024)"
        case .extended: "Extended (1-10000)"
        case .web: "Web Ports"
        case .database: "Database Ports"
        case .mail: "Mail Ports"
        case .custom: "Custom Range"
        }
    }

    var ports: [Int] {
        switch self {
        case .common: [20, 21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 993, 995, 3306, 3389, 5432, 5900, 8080, 8443]
        case .wellKnown: Array(1...1024)
        case .extended: Array(1...10000)
        case .web: [80, 443, 8080, 8443, 3000, 5000, 8000]
        case .database: [1433, 1521, 3306, 5432, 6379, 27017]
        case .mail: [25, 110, 143, 465, 587, 993, 995]
        case .custom: []
        }
    }
}
