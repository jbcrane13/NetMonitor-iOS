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
    private(set) var scanPhase: ScanPhase = .idle
    private(set) var lastScanDate: Date?
    
    enum ScanPhase: String {
        case idle = ""
        case tcpProbe = "Probing ports…"
        case bonjour = "Bonjour discovery…"
        case ssdp = "UPnP discovery…"
        case companion = "Mac companion…"
        case resolving = "Resolving names…"
        case done = "Complete"
    }
    
    private var scanTask: Task<Void, Never>?
    private let maxConcurrent = 40
    private let nameResolver = DeviceNameResolver()
    private nonisolated static let probeQueue = DispatchQueue(label: "com.netmonitor.probe", qos: .userInitiated, attributes: .concurrent)
    
    /// Key ports to probe — covers most device types without creating too many connections.
    /// HTTP, HTTPS, SSH, SMB, AirPlay
    // Broad port list to catch more device types:
    // 80/443: web UIs (routers, NAS, cameras)
    // 22: SSH (Linux, Mac, NAS)
    // 445: SMB (Windows, NAS)
    // 7000: AirPlay
    // 8080/8443: alt web (cameras, smart home hubs)
    // 5353: mDNS (Apple devices, Chromecasts)
    // 62078: Apple lockdownd (iPhones/iPads)
    // 9100: printers
    // 1883: MQTT (IoT hubs)
    // 554: RTSP (IP cameras)
    // 548: AFP (older Macs/NAS)
    private nonisolated static let probePorts: [UInt16] = [
        80, 443, 22, 445, 7000,
        8080, 8443, 62078, 5353,
        9100, 1883, 554, 548
    ]
    
    func scanNetwork(subnet: String? = nil) async {
        guard !isScanning else { return }
        
        isScanning = true
        scanProgress = 0
        scanPhase = .tcpProbe
        discoveredDevices = []
        
        defer {
            isScanning = false
            scanPhase = .idle
            lastScanDate = Date()
        }
        
        let baseIP = subnet ?? NetworkUtilities.detectSubnet() ?? "192.168.1"
        
        // If paired with Mac, kick off its scan early (it runs in parallel)
        let macConnection = MacConnectionService.shared
        if macConnection.connectionState.isConnected {
            await macConnection.send(command: CommandPayload(action: .scanDevices))
        }
        
        // Phase 1: Bonjour discovery — start early, let it accumulate during TCP probes
        let bonjourService = BonjourDiscoveryService()
        bonjourService.startDiscovery()
        
        // Phase 2: Multi-port TCP probes
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
                // TCP probes are 0–70% of progress
                scanProgress = Double(scannedCount) / Double(totalHosts) * 0.70
                
                if let device = result {
                    discoveredDevices.append(device)
                }
            }
        }
        
        // Phase 3: Give Bonjour extra time if it hasn't had enough
        // TCP probes take ~5-7s; Bonjour needs at least 8s to discover most devices
        scanPhase = .bonjour
        scanProgress = 0.72
        try? await Task.sleep(for: .seconds(3))
        
        // Merge Bonjour-discovered devices
        await mergeBonjourDevices(bonjourService)
        bonjourService.stopDiscovery()
        scanProgress = 0.78
        
        // Phase 4: SSDP/UPnP multicast discovery — catches devices that don't have
        // open TCP ports (smart TVs, game consoles, media players, Hue bridges, etc.)
        scanPhase = .ssdp
        await mergeSSDP(baseIP: baseIP)
        scanProgress = 0.84
        
        // Phase 5: Merge Mac companion devices (ARP scan results we can't get on iOS)
        scanPhase = .companion
        if macConnection.connectionState.isConnected {
            // Request refreshed results now that Mac has had time to scan
            await macConnection.send(command: CommandPayload(action: .refreshDevices))
            try? await Task.sleep(for: .seconds(1))
        }
        mergeCompanionDevices()
        scanProgress = 0.90
        
        // Phase 6: Resolve hostnames via reverse DNS for devices that don't have one
        scanPhase = .resolving
        await resolveHostnames()
        scanProgress = 0.98
        
        // Final dedup by IP — keep the entry with the most info (hostname > no hostname)
        deduplicateByIP()
        
        discoveredDevices.sort { $0.ipAddress.ipSortKey < $1.ipAddress.ipSortKey }
        scanPhase = .done
        scanProgress = 1.0
    }
    
    // MARK: - SSDP / UPnP Discovery
    
    /// Send SSDP M-SEARCH multicast and collect responding device IPs.
    /// This catches UPnP devices (TVs, Rokus, Hue bridges, game consoles, etc.)
    /// that don't listen on common TCP ports.
    private nonisolated func discoverSSDP() async -> [String] {
        let multicastGroup = "239.255.255.250"
        let multicastPort: UInt16 = 1900
        let searchMessage = [
            "M-SEARCH * HTTP/1.1",
            "HOST: 239.255.255.250:1900",
            "MAN: \"ssdp:discover\"",
            "MX: 3",
            "ST: ssdp:all",
            "", ""
        ].joined(separator: "\r\n")
        
        guard let messageData = searchMessage.data(using: .utf8) else { return [] }
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(multicastGroup),
            port: NWEndpoint.Port(rawValue: multicastPort)!
        )
        let params = NWParameters.udp
        params.requiredInterfaceType = .wifi
        
        let connection = NWConnection(to: endpoint, using: params)
        defer { connection.cancel() }
        nonisolated(unsafe) let conn = connection
        
        // Wait for connection ready
        let ready: Bool = await withCheckedContinuation { continuation in
            let resumed = ResumeState()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    Task {
                        guard await resumed.tryResume() else { return }
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    Task {
                        guard await resumed.tryResume() else { return }
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }
            conn.start(queue: Self.probeQueue)
        }
        
        guard ready else { return [] }
        
        // Send M-SEARCH
        conn.send(content: messageData, completion: .contentProcessed { _ in })
        
        // Collect responses for 3 seconds
        var discoveredIPs: Set<String> = []
        let deadline = Date().addingTimeInterval(3.0)
        
        while Date() < deadline {
            let response: Data? = await withCheckedContinuation { continuation in
                let resumed = ResumeState()
                
                let timeoutTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard await resumed.tryResume() else { return }
                    continuation.resume(returning: nil)
                }
                
                conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        continuation.resume(returning: data)
                    }
                }
            }
            
            guard let data = response,
                  let text = String(data: data, encoding: .utf8) else {
                continue
            }
            
            // Extract the IP from the LOCATION header (e.g. "LOCATION: http://192.168.1.5:8080/...")
            // or from the response source (harder with NWConnection, so use LOCATION)
            if let locationRange = text.range(of: "LOCATION: http://", options: .caseInsensitive) {
                let afterPrefix = text[locationRange.upperBound...]
                if let colonOrSlash = afterPrefix.firstIndex(where: { $0 == ":" || $0 == "/" }) {
                    let ip = String(afterPrefix[afterPrefix.startIndex..<colonOrSlash])
                    if !ip.isEmpty {
                        discoveredIPs.insert(ip)
                    }
                }
            }
        }
        
        return Array(discoveredIPs)
    }
    
    /// Merge SSDP-discovered devices into the main list (only adds new IPs).
    private func mergeSSDP(baseIP: String) async {
        let ssdpIPs = await discoverSSDP()
        let existingIPs = Set(discoveredDevices.map(\.ipAddress))
        
        for ip in ssdpIPs {
            // Only add if on our subnet and not already found
            guard ip.hasPrefix(baseIP + "."), !existingIPs.contains(ip) else { continue }
            discoveredDevices.append(DiscoveredDevice(
                ipAddress: ip,
                hostname: nil,
                vendor: nil,
                macAddress: nil,
                latency: nil,
                discoveredAt: Date(),
                source: .ssdp
            ))
        }
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
                // nonisolated(unsafe) needed: NWConnection is non-Sendable but we need
                // it inside the @Sendable addTask closure and its nested callbacks
                nonisolated(unsafe) let conn = connection
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                        let resumed = ResumeState()
                        
                        let timeoutTask = Task {
                            try? await Task.sleep(for: .milliseconds(800))
                            guard await resumed.tryResume() else { return }
                            conn.cancel()
                            continuation.resume(returning: false)
                        }
                        
                        conn.stateUpdateHandler = { state in
                            switch state {
                            case .ready:
                                Task {
                                    guard await resumed.tryResume() else { return }
                                    timeoutTask.cancel()
                                    conn.cancel()
                                    continuation.resume(returning: true)
                                }
                            case .failed, .cancelled:
                                Task {
                                    guard await resumed.tryResume() else { return }
                                    timeoutTask.cancel()
                                    continuation.resume(returning: false)
                                }
                            default:
                                break
                            }
                        }
                        
                        conn.start(queue: Self.probeQueue)
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
    case bonjour
    case ssdp
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
            switch source {
            case .macCompanion: return "via Mac"
            case .ssdp: return "UPnP"
            case .bonjour: return "Bonjour"
            default: return "—"
            }
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

