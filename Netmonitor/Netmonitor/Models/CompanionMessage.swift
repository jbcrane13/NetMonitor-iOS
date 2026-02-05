import Foundation

// MARK: - Companion Message Protocol
/// Mirrors the macOS NetMonitor CompanionService message types.
/// Uses length-prefixed JSON framing: 4-byte big-endian length prefix + JSON payload.
/// JSON format: { "type": "<messageType>", "payload": { ... } }

enum CompanionMessage: Codable, Sendable {
    case statusUpdate(StatusUpdatePayload)
    case targetList(TargetListPayload)
    case deviceList(DeviceListPayload)
    case command(CommandPayload)
    case toolResult(ToolResultPayload)
    case error(ErrorPayload)
    case heartbeat(HeartbeatPayload)

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum MessageType: String, Codable {
        case statusUpdate
        case targetList
        case deviceList
        case command
        case toolResult
        case error
        case heartbeat
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .statusUpdate:
            let payload = try container.decode(StatusUpdatePayload.self, forKey: .payload)
            self = .statusUpdate(payload)
        case .targetList:
            let payload = try container.decode(TargetListPayload.self, forKey: .payload)
            self = .targetList(payload)
        case .deviceList:
            let payload = try container.decode(DeviceListPayload.self, forKey: .payload)
            self = .deviceList(payload)
        case .command:
            let payload = try container.decode(CommandPayload.self, forKey: .payload)
            self = .command(payload)
        case .toolResult:
            let payload = try container.decode(ToolResultPayload.self, forKey: .payload)
            self = .toolResult(payload)
        case .error:
            let payload = try container.decode(ErrorPayload.self, forKey: .payload)
            self = .error(payload)
        case .heartbeat:
            let payload = try container.decode(HeartbeatPayload.self, forKey: .payload)
            self = .heartbeat(payload)
        }
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .statusUpdate(let payload):
            try container.encode(MessageType.statusUpdate, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .targetList(let payload):
            try container.encode(MessageType.targetList, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .deviceList(let payload):
            try container.encode(MessageType.deviceList, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .command(let payload):
            try container.encode(MessageType.command, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .toolResult(let payload):
            try container.encode(MessageType.toolResult, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .error(let payload):
            try container.encode(MessageType.error, forKey: .type)
            try container.encode(payload, forKey: .payload)
        case .heartbeat(let payload):
            try container.encode(MessageType.heartbeat, forKey: .type)
            try container.encode(payload, forKey: .payload)
        }
    }
}

// MARK: - Payload Types

struct StatusUpdatePayload: Codable, Sendable {
    let isMonitoring: Bool
    let onlineTargets: Int
    let offlineTargets: Int
    let averageLatency: Double?
    let timestamp: Date
}

struct TargetListPayload: Codable, Sendable {
    let targets: [TargetInfo]
}

struct TargetInfo: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let host: String
    let port: Int?
    let isOnline: Bool
    let latency: Double?
    let lastChecked: Date?
}

struct DeviceListPayload: Codable, Sendable {
    let devices: [DeviceInfo]
}

struct DeviceInfo: Codable, Sendable, Identifiable {
    let id: String
    let name: String?
    let ipAddress: String
    let macAddress: String?
    let vendor: String?
    let isOnline: Bool
}

struct CommandPayload: Codable, Sendable {
    let action: CommandAction
    let target: String?
    let parameters: [String: String]?

    init(action: CommandAction, target: String? = nil, parameters: [String: String]? = nil) {
        self.action = action
        self.target = target
        self.parameters = parameters
    }
}

enum CommandAction: String, Codable, Sendable {
    case startMonitoring
    case stopMonitoring
    case scanDevices
    case ping
    case traceroute
    case portScan
    case dnsLookup
    case wakeOnLan
    case refreshTargets
    case refreshDevices
}

struct ToolResultPayload: Codable, Sendable {
    let toolName: String
    let success: Bool
    let output: String
    let timestamp: Date
}

struct ErrorPayload: Codable, Sendable {
    let code: Int
    let message: String
    let timestamp: Date
}

struct HeartbeatPayload: Codable, Sendable {
    let version: String
    let timestamp: Date
}

// MARK: - JSON Encoder/Decoder Configuration

extension CompanionMessage {
    /// Shared JSON encoder configured to match the macOS companion service format.
    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// Shared JSON decoder configured to match the macOS companion service format.
    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Encode this message to length-prefixed JSON data.
    /// Format: 4-byte big-endian length prefix + JSON payload.
    func encodeLengthPrefixed() throws -> Data {
        let jsonData = try Self.jsonEncoder.encode(self)
        var length = UInt32(jsonData.count).bigEndian
        var frameData = Data(bytes: &length, count: 4)
        frameData.append(jsonData)
        return frameData
    }

    /// Decode a CompanionMessage from JSON data (without length prefix).
    static func decode(from data: Data) throws -> CompanionMessage {
        try jsonDecoder.decode(CompanionMessage.self, from: data)
    }
}
