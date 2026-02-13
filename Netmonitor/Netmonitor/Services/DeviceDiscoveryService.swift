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

    private enum ScanFilter: Sendable {
        case prefix(String)
        case network(NetworkUtilities.IPv4Network)

        func contains(ipAddress: String) -> Bool {
            switch self {
            case .prefix(let prefix):
                return ipAddress.hasPrefix(prefix + ".")
            case .network(let network):
                return network.contains(ipAddress: ipAddress)
            }
        }
    }

    private struct ScanTarget: Sendable {
        let hosts: [String]
        let filter: ScanFilter
    }

    private var scanTask: Task<Void, Never>?
    private var discoveredIndexByIP: [String: Int] = [:]

    private let maxConcurrentHosts = 24
    private let maxHostsPerScan = 1024
    private let maxBonjourServiceResolves = 100
    private let maxBonjourResolveConcurrency = 8

    private let nameResolver = DeviceNameResolver()

    private nonisolated static let probeQueue = DispatchQueue(label: "com.netmonitor.probe", qos: .userInitiated, attributes: .concurrent)

    /// Stage 1 ports: high-yield services for most LAN devices.
    private nonisolated static let primaryProbePorts: [UInt16] = [80, 443, 22, 445]

    /// Stage 2 ports: broaden coverage for IoT, printers, media devices, and Apple services.
    private nonisolated static let secondaryProbePorts: [UInt16] = [7000, 8080, 8443, 62078, 5353, 9100, 1883, 554, 548]

    private nonisolated static let maxConcurrentPortProbes = 3
    private nonisolated static let primaryProbeTimeout: Duration = .milliseconds(700)
    private nonisolated static let secondaryProbeTimeout: Duration = .milliseconds(1200)

    func scanNetwork(subnet: String? = nil) async {
        guard !isScanning else { return }

        isScanning = true
        scanProgress = 0
        scanPhase = .tcpProbe
        resetDiscoveredDevices()

        defer {
            isScanning = false
            scanPhase = .idle
            lastScanDate = Date()
        }

        let scanTarget = makeScanTarget(subnet: subnet)

        // If paired with Mac, kick off its scan early (it runs in parallel)
        let macConnection = MacConnectionService.shared
        if macConnection.connectionState.isConnected {
            await macConnection.send(command: CommandPayload(action: .scanDevices))
        }

        // Phase 1: Bonjour discovery — start early, let it accumulate during TCP probes
        let bonjourService = BonjourDiscoveryService()
        bonjourService.startDiscovery()

        // Phase 2: TCP probes over computed host targets
        let totalHosts = scanTarget.hosts.count
        var scannedCount = 0

        if totalHosts > 0 {
            await withTaskGroup(of: DiscoveredDevice?.self) { group in
                var pending = 0
                var hostIterator = scanTarget.hosts.makeIterator()

                while isScanning {
                    while pending < maxConcurrentHosts, let ip = hostIterator.next() {
                        pending += 1
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
                        upsertDiscoveredDevice(device)
                    }
                }
            }
        } else {
            scanProgress = 0.70
        }

        // Phase 3: Give Bonjour extra time if it hasn't had enough
        // TCP probes take ~5-10s; Bonjour needs at least ~8s to discover most devices.
        scanPhase = .bonjour
        scanProgress = 0.72
        try? await Task.sleep(for: .seconds(3))

        // Merge Bonjour-discovered devices
        await mergeBonjourDevices(bonjourService, filter: scanTarget.filter)
        bonjourService.stopDiscovery()
        scanProgress = 0.78

        // Phase 4: SSDP/UPnP multicast discovery — catches devices that don't have
        // open TCP ports (smart TVs, game consoles, media players, Hue bridges, etc.)
        scanPhase = .ssdp
        await mergeSSDP(filter: scanTarget.filter)
        scanProgress = 0.84

        // Phase 5: Merge Mac companion devices (ARP scan results we can't get on iOS)
        scanPhase = .companion
        if macConnection.connectionState.isConnected {
            // Request refreshed results now that Mac has had time to scan.
            await macConnection.send(command: CommandPayload(action: .refreshDevices))
            try? await Task.sleep(for: .seconds(1))
        }
        mergeCompanionDevices(filter: scanTarget.filter)
        scanProgress = 0.90

        // Phase 6: Resolve hostnames via reverse DNS for devices that don't have one.
        scanPhase = .resolving
        await resolveHostnames()
        scanProgress = 0.98

        discoveredDevices.sort { $0.ipAddress.ipSortKey < $1.ipAddress.ipSortKey }
        rebuildDiscoveredIndexByIP()

        scanPhase = .done
        scanProgress = 1.0
    }

    // MARK: - Scan Target Planning

    private func makeScanTarget(subnet: String?) -> ScanTarget {
        let localIP = NetworkUtilities.detectLocalIPAddress()

        if let subnet, !subnet.isEmpty {
            return ScanTarget(
                hosts: hostsForSubnetPrefix(subnet, excluding: localIP),
                filter: .prefix(subnet)
            )
        }

        if let network = NetworkUtilities.detectLocalIPv4Network() {
            let hosts = network.hostAddresses(limit: maxHostsPerScan)
            if !hosts.isEmpty {
                return ScanTarget(hosts: hosts, filter: .network(network))
            }
        }

        let fallbackSubnet = NetworkUtilities.detectSubnet() ?? "192.168.1"
        return ScanTarget(
            hosts: hostsForSubnetPrefix(fallbackSubnet, excluding: localIP),
            filter: .prefix(fallbackSubnet)
        )
    }

    private func hostsForSubnetPrefix(_ subnet: String, excluding ipToSkip: String?) -> [String] {
        var hosts: [String] = []
        hosts.reserveCapacity(254)

        for host in 1...254 {
            let ip = "\(subnet).\(host)"
            if ip != ipToSkip {
                hosts.append(ip)
            }
        }

        return hosts
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

        // Wait for connection ready (with timeout to prevent hang).
        let ready: Bool = await withCheckedContinuation { continuation in
            let resumed = ResumeState()

            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard await resumed.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: false)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }
            connection.start(queue: Self.probeQueue)
        }

        guard ready else { return [] }

        // Send M-SEARCH
        connection.send(content: messageData, completion: .contentProcessed { _ in })

        // Collect responses for 3 seconds.
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

                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
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

            if let ip = Self.extractIPFromSSDPResponse(text) {
                discoveredIPs.insert(ip)
            }
        }

        return Array(discoveredIPs)
    }

    /// Merge SSDP-discovered devices into the main list (adds or enriches by IP).
    private func mergeSSDP(filter: ScanFilter) async {
        let ssdpIPs = await discoverSSDP()

        for ip in ssdpIPs where filter.contains(ipAddress: ip) {
            upsertDiscoveredDevice(DiscoveredDevice(
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

    /// Resolve hostnames for devices missing one via reverse DNS (PTR) lookup.
    private func resolveHostnames() async {
        let devicesNeedingNames = discoveredDevices.enumerated().filter { $0.element.hostname == nil }
        guard !devicesNeedingNames.isEmpty else { return }

        // Resolve concurrently but cap at 10 at a time to limit memory.
        let maxResolve = 10
        await withTaskGroup(of: (Int, String?).self) { group in
            var pending = 0
            var iterator = devicesNeedingNames.makeIterator()

            // Seed initial batch.
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

                // Add next from queue.
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
    private func mergeCompanionDevices(filter: ScanFilter) {
        guard let macDevices = MacConnectionService.shared.lastDeviceList?.devices else { return }

        for macDevice in macDevices where macDevice.isOnline {
            guard filter.contains(ipAddress: macDevice.ipAddress) else { continue }

            upsertDiscoveredDevice(DiscoveredDevice(
                ipAddress: macDevice.ipAddress,
                hostname: macDevice.hostname,
                vendor: macDevice.vendor,
                macAddress: macDevice.macAddress.isEmpty ? nil : macDevice.macAddress,
                latency: nil,
                discoveredAt: Date(),
                source: .macCompanion
            ))
        }
    }

    func stopScan() {
        isScanning = false
        scanTask?.cancel()
    }

    /// Probe a host with staged port groups and return first successful latency.
    private nonisolated func probeHost(_ ip: String) async -> DiscoveredDevice? {
        if let fastLatency = await Self.firstReachableLatency(
            ip: ip,
            ports: Self.primaryProbePorts,
            timeout: Self.primaryProbeTimeout,
            maxConcurrentPorts: Self.maxConcurrentPortProbes
        ) {
            return DiscoveredDevice(ipAddress: ip, latency: fastLatency, discoveredAt: Date())
        }

        guard let broadLatency = await Self.firstReachableLatency(
            ip: ip,
            ports: Self.secondaryProbePorts,
            timeout: Self.secondaryProbeTimeout,
            maxConcurrentPorts: Self.maxConcurrentPortProbes
        ) else {
            return nil
        }

        return DiscoveredDevice(ipAddress: ip, latency: broadLatency, discoveredAt: Date())
    }

    private nonisolated static func firstReachableLatency(
        ip: String,
        ports: [UInt16],
        timeout: Duration,
        maxConcurrentPorts: Int
    ) async -> Double? {
        guard !ports.isEmpty else { return nil }

        return await withTaskGroup(of: Double?.self, returning: Double?.self) { group in
            var pending = 0
            var iterator = ports.makeIterator()

            while pending < maxConcurrentPorts, let port = iterator.next() {
                pending += 1
                group.addTask {
                    await probePort(ip: ip, port: port, timeout: timeout)
                }
            }

            while pending > 0 {
                guard let result = await group.next() else { break }
                pending -= 1

                if let latency = result {
                    group.cancelAll()
                    return latency
                }

                if let port = iterator.next() {
                    pending += 1
                    group.addTask {
                        await probePort(ip: ip, port: port, timeout: timeout)
                    }
                }
            }

            return nil
        }
    }

    private nonisolated static func probePort(ip: String, port: UInt16, timeout: Duration) async -> Double? {
        let host = NWEndpoint.Host(ip)
        let endpoint = NWEndpoint.hostPort(host: host, port: NWEndpoint.Port(rawValue: port)!)
        let params = NWParameters.tcp
        params.requiredInterfaceType = .wifi

        let connection = NWConnection(to: endpoint, using: params)
        defer { connection.cancel() }

        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let resumed = ResumeState()

            let timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                guard await resumed.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: nil)
            }

            // Capture start time immediately before starting the connection so we
            // measure only handshake latency and not task scheduling overhead.
            let start = Date()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()
                        continuation.resume(returning: elapsed)
                    }
                case .failed(let error):
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()

                        // A fast refusal indicates the host is reachable even if the
                        // probed service is closed.
                        if case NWError.posix(let code) = error, code == .ECONNREFUSED {
                            continuation.resume(returning: elapsed)
                        } else {
                            continuation.resume(returning: nil)
                        }
                    }
                case .cancelled:
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()
                        continuation.resume(returning: nil)
                    }
                default:
                    break
                }
            }

            connection.start(queue: Self.probeQueue)
        }
    }

    /// Merge devices found via Bonjour service browsing into the device list.
    /// Resolves services concurrently (bounded) and merges by IP address.
    private func mergeBonjourDevices(_ bonjourService: BonjourDiscoveryService, filter: ScanFilter) async {
        let services = Array(uniqueBonjourServices(from: bonjourService.discoveredServices).prefix(maxBonjourServiceResolves))
        guard !services.isEmpty else { return }

        await withTaskGroup(of: DiscoveredDevice?.self) { group in
            var pending = 0
            var iterator = services.makeIterator()

            while pending < maxBonjourResolveConcurrency, let service = iterator.next() {
                pending += 1
                group.addTask { [filter] in
                    await Self.makeBonjourDevice(from: service, filter: filter)
                }
            }

            while pending > 0 {
                guard let result = await group.next() else { break }
                pending -= 1

                if let device = result {
                    upsertDiscoveredDevice(device)
                }

                if let next = iterator.next() {
                    pending += 1
                    group.addTask { [filter] in
                        await Self.makeBonjourDevice(from: next, filter: filter)
                    }
                }
            }
        }
    }

    private nonisolated static func makeBonjourDevice(from service: BonjourService, filter: ScanFilter) async -> DiscoveredDevice? {
        guard let host = await resolveBonjourHost(for: service) else {
            return nil
        }

        let normalizedHost = host.split(separator: "%", maxSplits: 1).first.map(String.init) ?? host
        let candidateIPs: [String]
        if let ip = cleanedIPv4Address(normalizedHost) {
            candidateIPs = [ip]
        } else {
            candidateIPs = await resolveIPv4Addresses(for: normalizedHost)
        }

        guard let matchedIP = candidateIPs.first(where: { filter.contains(ipAddress: $0) }) else {
            return nil
        }

        return DiscoveredDevice(
            ipAddress: matchedIP,
            hostname: service.name,
            vendor: nil,
            macAddress: nil,
            latency: nil,
            discoveredAt: Date(),
            source: .bonjour
        )
    }

    private nonisolated static func resolveBonjourHost(for service: BonjourService) async -> String? {
        let endpoint = NWEndpoint.service(
            name: service.name,
            type: service.type,
            domain: service.domain,
            interface: nil
        )

        let params = NWParameters.tcp

        let connection = NWConnection(to: endpoint, using: params)
        defer { connection.cancel() }

        return await withCheckedContinuation { continuation in
            let resumed = ResumeState()

            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard await resumed.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: nil)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let resolvedHost: String?
                    if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                       case let .hostPort(host, _) = innerEndpoint {
                        resolvedHost = "\(host)"
                    } else {
                        resolvedHost = nil
                    }

                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()
                        continuation.resume(returning: resolvedHost)
                    }
                case .failed, .cancelled:
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()
                        continuation.resume(returning: nil)
                    }
                default:
                    break
                }
            }

            connection.start(queue: Self.probeQueue)
        }
    }

    private nonisolated static func resolveIPv4Addresses(for host: String) async -> [String] {
        await withCheckedContinuation { continuation in
            let cfHost = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
            var streamError = CFStreamError()

            guard CFHostStartInfoResolution(cfHost, .addresses, &streamError),
                  let addresses = CFHostGetAddressing(cfHost, nil)?.takeUnretainedValue() as? [Data] else {
                continuation.resume(returning: [])
                return
            }

            var resolved: Set<String> = []
            resolved.reserveCapacity(addresses.count)

            for addressData in addresses {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                addressData.withUnsafeBytes { ptr in
                    guard let sockaddr = ptr.bindMemory(to: sockaddr.self).baseAddress else { return }
                    getnameinfo(
                        sockaddr,
                        socklen_t(addressData.count),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                }

                let length = strnlen(hostname, hostname.count)
                let bytes = hostname.prefix(length).map { UInt8(bitPattern: $0) }
                let ip = String(decoding: bytes, as: UTF8.self)

                if isValidIPv4Address(ip) {
                    resolved.insert(ip)
                }
            }

            continuation.resume(returning: Array(resolved))
        }
    }

    private nonisolated static func extractIPFromSSDPResponse(_ response: String) -> String? {
        for line in response.split(whereSeparator: \.isNewline) {
            if line.lowercased().hasPrefix("location:"),
               let ip = firstIPv4Address(in: String(line)) {
                return ip
            }
        }

        return firstIPv4Address(in: response)
    }

    private nonisolated static func firstIPv4Address(in text: String) -> String? {
        let tokens = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
        for token in tokens where isValidIPv4Address(token) {
            return token
        }
        return nil
    }

    private nonisolated static func cleanedIPv4Address(_ host: String) -> String? {
        let cleaned = host.split(separator: "%", maxSplits: 1).first.map(String.init) ?? host
        guard isValidIPv4Address(cleaned) else { return nil }
        return cleaned
    }

    private nonisolated static func isValidIPv4Address(_ value: String) -> Bool {
        let components = value.split(separator: ".")
        guard components.count == 4 else { return false }

        for component in components {
            guard let octet = UInt8(component) else { return false }
            let componentText = String(component)
            if String(octet) != componentText && componentText != "0" {
                return false
            }
        }
        return true
    }

    private func uniqueBonjourServices(from services: [BonjourService]) -> [BonjourService] {
        var unique: [BonjourService] = []
        unique.reserveCapacity(min(services.count, maxBonjourServiceResolves))

        var seen: Set<String> = []
        for service in services {
            let key = "\(service.name)|\(service.type)|\(service.domain)"
            if seen.insert(key).inserted {
                unique.append(service)
            }
        }

        return unique
    }

    // MARK: - Dedup / Merge Helpers

    private func resetDiscoveredDevices() {
        discoveredDevices = []
        discoveredIndexByIP = [:]
    }

    private func rebuildDiscoveredIndexByIP() {
        discoveredIndexByIP = [:]
        discoveredIndexByIP.reserveCapacity(discoveredDevices.count)

        for (index, device) in discoveredDevices.enumerated() {
            discoveredIndexByIP[device.ipAddress] = index
        }
    }

    private func upsertDiscoveredDevice(_ device: DiscoveredDevice) {
        if let existingIndex = discoveredIndexByIP[device.ipAddress] {
            let existing = discoveredDevices[existingIndex]
            discoveredDevices[existingIndex] = mergedDevice(existing: existing, incoming: device)
        } else {
            discoveredIndexByIP[device.ipAddress] = discoveredDevices.count
            discoveredDevices.append(device)
        }
    }

    private func mergedDevice(existing: DiscoveredDevice, incoming: DiscoveredDevice) -> DiscoveredDevice {
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
