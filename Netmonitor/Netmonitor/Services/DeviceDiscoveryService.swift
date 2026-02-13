import Foundation
import Network
import SwiftData

@MainActor
@Observable
final class DeviceDiscoveryService {
    static let shared = DeviceDiscoveryService()
    
    private(set) var discoveredDevices: [DiscoveredDevice] = []
    private(set) var isScanning: Bool = false
    private(set) var scanProgress: Double = 0
    private(set) var lastScanDate: Date?
    
    private var scanTask: Task<Void, Never>?
    private let maxConcurrent = 20
    private let nameResolver = DeviceNameResolver()
    private nonisolated static let probeQueue = DispatchQueue(label: "com.netmonitor.probe", qos: .userInitiated, attributes: .concurrent)
    
    /// Key ports to probe — covers most device types without creating too many connections.
    /// HTTP, HTTPS, SSH, SMB, AirPlay
    private nonisolated static let probePorts: [UInt16] = [80, 443, 22, 445, 7000]
    
    func scanNetwork(subnet: String? = nil) async {
        guard !isScanning else { return }
        
        isScanning = true
        scanProgress = 0
        discoveredDevices = []
        
        defer {
            isScanning = false
            lastScanDate = Date()
        }
        
        // If paired with Mac, request its device list (ARP + Bonjour)
        let macConnection = MacConnectionService.shared
        if macConnection.connectionState.isConnected {
            await macConnection.send(command: CommandPayload(action: .scanDevices))
            // Give Mac a moment to scan, then request results
            try? await Task.sleep(for: .seconds(2))
            await macConnection.send(command: CommandPayload(action: .refreshDevices))
        }
        
        // Phase 1: Bonjour discovery (runs concurrently with TCP probes)
        let bonjourService = BonjourDiscoveryService()
        bonjourService.startDiscovery()
        
        // Phase 2: Multi-port TCP probes
        let baseIP = subnet ?? NetworkUtilities.detectSubnet() ?? "192.168.1"
        let totalHosts = 254
        var scannedCount = 0
        
        await withTaskGroup(of: DiscoveredDevice?.self) { group in
            var pending = 0
            var hostIterator = (1...254).makeIterator()
            
            while isScanning {
                while pending < maxConcurrent, let host = hostIterator.next() {
                    pending += 1
                    let ip = "\(baseIP).\(host)"
                    
                    group.addTask { [weak self] in
                        await self?.probeHost(ip)
                    }
                }
                
                guard let result = await group.next() else { break }
                pending -= 1
                scannedCount += 1
                scanProgress = Double(scannedCount) / Double(totalHosts)
                
                if let device = result {
                    discoveredDevices.append(device)
                }
            }
        }
        
        // Phase 3: Merge Bonjour-discovered devices
        await mergeBonjourDevices(bonjourService)
        bonjourService.stopDiscovery()
        
        // Phase 4: Merge Mac companion devices (ARP scan results we can't get on iOS)
        mergeCompanionDevices()
        
        // Phase 5: Resolve hostnames via reverse DNS for devices that don't have one
        await resolveHostnames()
        
        // Final dedup by IP — keep the entry with the most info (hostname > no hostname)
        deduplicateByIP()
        
        discoveredDevices.sort { $0.ipAddress.ipSortKey < $1.ipAddress.ipSortKey }
    }
    
    /// Remove duplicate entries for the same IP, keeping the most enriched version.
    private func deduplicateByIP() {
        var seen: [String: Int] = [:]
        var toRemove: IndexSet = []
        
        for (index, device) in discoveredDevices.enumerated() {
            if let existingIndex = seen[device.ipAddress] {
                // Keep whichever has more info
                let existing = discoveredDevices[existingIndex]
                let newHasMore = (device.hostname != nil && existing.hostname == nil)
                    || (device.vendor != nil && existing.vendor == nil)
                    || (device.macAddress != nil && existing.macAddress == nil)
                
                if newHasMore {
                    // Replace existing with this richer entry
                    toRemove.insert(existingIndex)
                    seen[device.ipAddress] = index
                } else {
                    // Discard this duplicate
                    toRemove.insert(index)
                }
            } else {
                seen[device.ipAddress] = index
            }
        }
        
        // Remove in reverse order to preserve indices
        for index in toRemove.sorted().reversed() {
            discoveredDevices.remove(at: index)
        }
    }
    
    /// Resolve hostnames for devices missing one via reverse DNS (PTR) lookup.
    private func resolveHostnames() async {
        let devicesNeedingNames = discoveredDevices.enumerated().filter { $0.element.hostname == nil }
        guard !devicesNeedingNames.isEmpty else { return }
        
        // Resolve concurrently but cap at 10 at a time to limit memory
        let maxResolve = 10
        await withTaskGroup(of: (Int, String?).self) { group in
            var pending = 0
            var iterator = devicesNeedingNames.makeIterator()
            
            // Seed initial batch
            while pending < maxResolve, let (index, device) = iterator.next() {
                pending += 1
                group.addTask { [nameResolver] in
                    let name = await nameResolver.resolve(ipAddress: device.ipAddress, bonjourServices: [])
                    return (index, name)
                }
            }
            
            for await (index, hostname) in group {
                pending -= 1
                
                if let hostname, index < discoveredDevices.count {
                    let existing = discoveredDevices[index]
                    discoveredDevices[index] = DiscoveredDevice(
                        ipAddress: existing.ipAddress,
                        hostname: hostname,
                        vendor: existing.vendor,
                        macAddress: existing.macAddress,
                        latency: existing.latency,
                        discoveredAt: existing.discoveredAt,
                        source: existing.source
                    )
                }
                
                // Add next from queue
                if let (nextIndex, nextDevice) = iterator.next() {
                    pending += 1
                    group.addTask { [nameResolver] in
                        let name = await nameResolver.resolve(ipAddress: nextDevice.ipAddress, bonjourServices: [])
                        return (nextIndex, name)
                    }
                }
            }
        }
    }
    
    /// Merge devices discovered by the paired Mac into local results.
    /// Mac provides ARP + Bonjour data; we deduplicate by IP and enrich local entries.
    private func mergeCompanionDevices() {
        guard let macDevices = MacConnectionService.shared.lastDeviceList?.devices else { return }
        
        let localIPs = Set(discoveredDevices.map(\.ipAddress))
        
        for macDevice in macDevices where macDevice.isOnline {
            if localIPs.contains(macDevice.ipAddress) {
                // Enrich existing entry with Mac's hostname/vendor data
                if let index = discoveredDevices.firstIndex(where: { $0.ipAddress == macDevice.ipAddress }) {
                    let existing = discoveredDevices[index]
                    discoveredDevices[index] = DiscoveredDevice(
                        ipAddress: existing.ipAddress,
                        hostname: macDevice.hostname ?? existing.hostname,
                        vendor: macDevice.vendor ?? existing.vendor,
                        macAddress: macDevice.macAddress.isEmpty ? existing.macAddress : macDevice.macAddress,
                        latency: existing.latency,
                        discoveredAt: existing.discoveredAt,
                        source: existing.source
                    )
                }
            } else {
                // New device only Mac found (via ARP) — add it
                discoveredDevices.append(DiscoveredDevice(
                    ipAddress: macDevice.ipAddress,
                    hostname: macDevice.hostname,
                    vendor: macDevice.vendor,
                    macAddress: macDevice.macAddress,
                    latency: nil,
                    discoveredAt: Date(),
                    source: .macCompanion
                ))
            }
        }
    }
    
    func stopScan() {
        isScanning = false
        scanTask?.cancel()
    }
    
    /// Probe a host by trying a few common ports concurrently.
    /// Returns as soon as ANY port responds. All connections are explicitly cancelled on exit.
    private nonisolated func probeHost(_ ip: String) async -> DiscoveredDevice? {
        let start = Date()
        let host = NWEndpoint.Host(ip)
        
        // Create all connections upfront so we can cancel them all on exit
        let connections: [(NWConnection, UInt16)] = Self.probePorts.map { port in
            let endpoint = NWEndpoint.hostPort(host: host, port: NWEndpoint.Port(rawValue: port)!)
            let params = NWParameters.tcp
            params.requiredInterfaceType = .wifi
            return (NWConnection(to: endpoint, using: params), port)
        }
        
        // Ensure ALL connections are cancelled when we exit, no matter what
        defer {
            for (conn, _) in connections {
                conn.cancel()
            }
        }
        
        let reachable = await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for (connection, _) in connections {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                        let resumed = ResumeState()
                        
                        connection.stateUpdateHandler = { state in
                            Task {
                                guard await !resumed.hasResumed else { return }
                                switch state {
                                case .ready:
                                    await resumed.setResumed()
                                    continuation.resume(returning: true)
                                case .failed, .cancelled:
                                    await resumed.setResumed()
                                    continuation.resume(returning: false)
                                default:
                                    break
                                }
                            }
                        }
                        
                        connection.start(queue: Self.probeQueue)
                        
                        // Timeout
                        Task {
                            try? await Task.sleep(for: .milliseconds(600))
                            guard await !resumed.hasResumed else { return }
                            await resumed.setResumed()
                            connection.cancel()
                            continuation.resume(returning: false)
                        }
                    }
                }
            }
            
            for await result in group {
                if result {
                    group.cancelAll()
                    return true
                }
            }
            return false
        }
        
        guard reachable else { return nil }
        
        let latency = Date().timeIntervalSince(start) * 1000
        return DiscoveredDevice(ipAddress: ip, latency: latency, discoveredAt: Date())
    }
    
    /// Merge devices found via Bonjour service browsing into the device list.
    /// Resolves each service to get its IP, then merges by IP address.
    private func mergeBonjourDevices(_ bonjourService: BonjourDiscoveryService) async {
        var knownIPs = Set(discoveredDevices.map(\.ipAddress))
        
        // Limit resolution to avoid creating too many NWConnections
        let services = Array(bonjourService.discoveredServices.prefix(30))
        for service in services {
            if let resolved = await bonjourService.resolveService(service) {
                if let host = resolved.hostName {
                    // Strip interface suffix (e.g., "%en0") and validate as IP
                    let cleaned = host.replacingOccurrences(of: "%.*", with: "", options: .regularExpression)
                    
                    // Only use if it looks like an IP address (not a hostname like "Mac.local")
                    guard !cleaned.isEmpty, cleaned.contains("."),
                          cleaned.split(separator: ".").count == 4,
                          cleaned.split(separator: ".").allSatisfy({ Int($0) != nil }) else {
                        continue
                    }
                    
                    let ip = cleaned
                    
                    if knownIPs.contains(ip) {
                        // Enrich existing entry with Bonjour name if it doesn't have one
                        if let index = discoveredDevices.firstIndex(where: { $0.ipAddress == ip }),
                           discoveredDevices[index].hostname == nil {
                            let existing = discoveredDevices[index]
                            discoveredDevices[index] = DiscoveredDevice(
                                ipAddress: existing.ipAddress,
                                hostname: service.name,
                                vendor: existing.vendor,
                                macAddress: existing.macAddress,
                                latency: existing.latency,
                                discoveredAt: existing.discoveredAt,
                                source: existing.source
                            )
                        }
                    } else {
                        // New device found only via Bonjour
                        discoveredDevices.append(DiscoveredDevice(
                            ipAddress: ip,
                            hostname: service.name,
                            vendor: nil,
                            macAddress: nil,
                            latency: nil,
                            discoveredAt: Date(),
                            source: .local
                        ))
                        knownIPs.insert(ip)
                    }
                }
            }
        }
    }
    
}

enum DeviceSource: Sendable {
    case local
    case macCompanion
}

struct DiscoveredDevice: Identifiable, Sendable {
    let id = UUID()
    let ipAddress: String
    let hostname: String?
    let vendor: String?
    let macAddress: String?
    let latency: Double?
    let discoveredAt: Date
    let source: DeviceSource
    
    /// Convenience init for local TCP probe (backward compatible)
    init(ipAddress: String, latency: Double, discoveredAt: Date) {
        self.ipAddress = ipAddress
        self.hostname = nil
        self.vendor = nil
        self.macAddress = nil
        self.latency = latency
        self.discoveredAt = discoveredAt
        self.source = .local
    }
    
    /// Full init with all fields
    init(ipAddress: String, hostname: String?, vendor: String?, macAddress: String?, latency: Double?, discoveredAt: Date, source: DeviceSource) {
        self.ipAddress = ipAddress
        self.hostname = hostname
        self.vendor = vendor
        self.macAddress = macAddress
        self.latency = latency
        self.discoveredAt = discoveredAt
        self.source = source
    }
    
    var displayName: String {
        hostname ?? ipAddress
    }
    
    var latencyText: String {
        guard let latency else {
            return source == .macCompanion ? "via Mac" : "—"
        }
        if latency < 1 {
            return "<1 ms"
        }
        return String(format: "%.0f ms", latency)
    }
}

extension String {
    var ipSortKey: Int {
        let parts = self.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return 0 }
        return parts[0] * 16777216 + parts[1] * 65536 + parts[2] * 256 + parts[3]
    }
}

