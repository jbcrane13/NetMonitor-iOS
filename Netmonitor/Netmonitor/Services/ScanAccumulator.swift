import Foundation

/// Thread-safe accumulator for discovered devices during network scanning.
/// Replaces the unsafe `@unchecked Sendable` mutable state in DeviceDiscoveryService.
actor ScanAccumulator {
    private var devices: [DiscoveredDevice] = []
    private var indexByIP: [String: Int] = [:]

    func upsert(_ device: DiscoveredDevice) {
        if let existingIndex = indexByIP[device.ipAddress] {
            let existing = devices[existingIndex]
            devices[existingIndex] = Self.merged(existing: existing, incoming: device)
        } else {
            indexByIP[device.ipAddress] = devices.count
            devices.append(device)
        }
    }

    func contains(ip: String) -> Bool {
        indexByIP[ip] != nil
    }

    func knownIPs() -> Set<String> {
        Set(indexByIP.keys)
    }

    func snapshot() -> [DiscoveredDevice] {
        devices
    }

    func sortedSnapshot() -> [DiscoveredDevice] {
        devices.sorted { $0.ipAddress.ipSortKey < $1.ipAddress.ipSortKey }
    }

    func reset() {
        devices = []
        indexByIP = [:]
    }

    var count: Int { devices.count }

    private static func merged(existing: DiscoveredDevice, incoming: DiscoveredDevice) -> DiscoveredDevice {
        DiscoveredDevice(
            ipAddress: existing.ipAddress,
            hostname: existing.hostname ?? incoming.hostname,
            vendor: existing.vendor ?? incoming.vendor,
            macAddress: existing.macAddress ?? incoming.macAddress,
            latency: existing.latency ?? incoming.latency,
            discoveredAt: existing.discoveredAt,
            source: existing.source
        )
    }
}
