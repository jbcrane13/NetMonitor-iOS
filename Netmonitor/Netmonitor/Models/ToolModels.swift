import Foundation

struct PingResult: Identifiable, Sendable {
    let id = UUID()
    let sequence: Int
    let host: String
    let ipAddress: String?
    let ttl: Int
    let time: Double
    let size: Int
    let timestamp: Date
    
    init(
        sequence: Int,
        host: String,
        ipAddress: String? = nil,
        ttl: Int,
        time: Double,
        size: Int = 64
    ) {
        self.sequence = sequence
        self.host = host
        self.ipAddress = ipAddress
        self.ttl = ttl
        self.time = time
        self.size = size
        self.timestamp = Date()
    }
    
    var timeText: String {
        if time < 1 {
            return String(format: "%.2f ms", time)
        }
        return String(format: "%.1f ms", time)
    }
}

struct PingStatistics: Sendable {
    let host: String
    let transmitted: Int
    let received: Int
    let packetLoss: Double
    let minTime: Double
    let maxTime: Double
    let avgTime: Double
    let stdDev: Double?
    
    var packetLossText: String {
        String(format: "%.1f%%", packetLoss)
    }
    
    var successRate: Double {
        guard transmitted > 0 else { return 0 }
        return Double(received) / Double(transmitted) * 100
    }
}

struct TracerouteHop: Identifiable, Sendable {
    let id = UUID()
    let hopNumber: Int
    let ipAddress: String?
    let hostname: String?
    let times: [Double]
    let isTimeout: Bool
    let timestamp: Date
    
    init(
        hopNumber: Int,
        ipAddress: String? = nil,
        hostname: String? = nil,
        times: [Double] = [],
        isTimeout: Bool = false
    ) {
        self.hopNumber = hopNumber
        self.ipAddress = ipAddress
        self.hostname = hostname
        self.times = times
        self.isTimeout = isTimeout
        self.timestamp = Date()
    }
    
    var displayAddress: String {
        if isTimeout { return "*" }
        return hostname ?? ipAddress ?? "*"
    }
    
    var averageTime: Double? {
        guard !times.isEmpty else { return nil }
        return times.reduce(0, +) / Double(times.count)
    }
    
    var timeText: String {
        if isTimeout { return "*" }
        guard let avg = averageTime else { return "*" }
        return String(format: "%.1f ms", avg)
    }
}

struct PortScanResult: Identifiable, Sendable {
    let id = UUID()
    let port: Int
    let state: PortState
    let serviceName: String?
    let banner: String?
    let responseTime: Double?
    
    init(
        port: Int,
        state: PortState,
        serviceName: String? = nil,
        banner: String? = nil,
        responseTime: Double? = nil
    ) {
        self.port = port
        self.state = state
        self.serviceName = serviceName ?? Self.commonServiceName(for: port)
        self.banner = banner
        self.responseTime = responseTime
    }
    
    static func commonServiceName(for port: Int) -> String? {
        let services: [Int: String] = [
            20: "FTP Data", 21: "FTP", 22: "SSH", 23: "Telnet",
            25: "SMTP", 53: "DNS", 67: "DHCP", 68: "DHCP",
            80: "HTTP", 110: "POP3", 119: "NNTP", 123: "NTP",
            143: "IMAP", 161: "SNMP", 194: "IRC", 443: "HTTPS",
            465: "SMTPS", 514: "Syslog", 587: "Submission",
            993: "IMAPS", 995: "POP3S", 1433: "MSSQL", 1521: "Oracle",
            3306: "MySQL", 3389: "RDP", 5432: "PostgreSQL",
            5900: "VNC", 6379: "Redis", 8080: "HTTP Alt",
            8443: "HTTPS Alt", 27017: "MongoDB"
        ]
        return services[port]
    }
}

enum PortState: String, Sendable {
    case open
    case closed
    case filtered
    
    var displayName: String {
        rawValue.capitalized
    }
}

struct DNSRecord: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let type: DNSRecordType
    let value: String
    let ttl: Int
    let priority: Int?
    
    init(
        name: String,
        type: DNSRecordType,
        value: String,
        ttl: Int,
        priority: Int? = nil
    ) {
        self.name = name
        self.type = type
        self.value = value
        self.ttl = ttl
        self.priority = priority
    }
    
    var ttlText: String {
        if ttl >= 86400 {
            return "\(ttl / 86400)d"
        } else if ttl >= 3600 {
            return "\(ttl / 3600)h"
        } else if ttl >= 60 {
            return "\(ttl / 60)m"
        }
        return "\(ttl)s"
    }
}

struct DNSQueryResult: Sendable {
    let domain: String
    let server: String
    let queryType: DNSRecordType
    let records: [DNSRecord]
    let queryTime: Double
    let timestamp: Date
    
    init(
        domain: String,
        server: String,
        queryType: DNSRecordType,
        records: [DNSRecord],
        queryTime: Double
    ) {
        self.domain = domain
        self.server = server
        self.queryType = queryType
        self.records = records
        self.queryTime = queryTime
        self.timestamp = Date()
    }
    
    var queryTimeText: String {
        String(format: "%.0f ms", queryTime)
    }
}

struct BonjourService: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let type: String
    let domain: String
    let hostName: String?
    let port: Int?
    let txtRecords: [String: String]
    let addresses: [String]
    let discoveredAt: Date
    
    init(
        name: String,
        type: String,
        domain: String = "local.",
        hostName: String? = nil,
        port: Int? = nil,
        txtRecords: [String: String] = [:],
        addresses: [String] = []
    ) {
        self.name = name
        self.type = type
        self.domain = domain
        self.hostName = hostName
        self.port = port
        self.txtRecords = txtRecords
        self.addresses = addresses
        self.discoveredAt = Date()
    }
    
    var fullType: String {
        "\(type).\(domain)"
    }
    
    var serviceCategory: String {
        switch type {
        case "_http._tcp", "_https._tcp": "Web"
        case "_ssh._tcp", "_sftp._tcp": "Remote Access"
        case "_smb._tcp", "_afpovertcp._tcp": "File Sharing"
        case "_printer._tcp", "_ipp._tcp": "Printing"
        case "_airplay._tcp", "_raop._tcp": "AirPlay"
        case "_googlecast._tcp": "Chromecast"
        case "_spotify-connect._tcp": "Spotify"
        case "_homekit._tcp": "HomeKit"
        default: "Other"
        }
    }
}

struct WHOISResult: Sendable {
    let query: String
    let registrar: String?
    let creationDate: Date?
    let expirationDate: Date?
    let updatedDate: Date?
    let nameServers: [String]
    let status: [String]
    let rawData: String
    let queriedAt: Date
    
    init(
        query: String,
        registrar: String? = nil,
        creationDate: Date? = nil,
        expirationDate: Date? = nil,
        updatedDate: Date? = nil,
        nameServers: [String] = [],
        status: [String] = [],
        rawData: String
    ) {
        self.query = query
        self.registrar = registrar
        self.creationDate = creationDate
        self.expirationDate = expirationDate
        self.updatedDate = updatedDate
        self.nameServers = nameServers
        self.status = status
        self.rawData = rawData
        self.queriedAt = Date()
    }
    
    var domainAge: String? {
        guard let creation = creationDate else { return nil }
        let years = Calendar.current.dateComponents([.year], from: creation, to: Date()).year ?? 0
        return "\(years) years"
    }
    
    var daysUntilExpiration: Int? {
        guard let expiration = expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiration).day
    }
}
