import Foundation
import Network
import SwiftData

@MainActor
@Observable
final class DeviceDiscoveryService {
    /// Shared instance for app-wide use. Prefer injecting via init for testability.
    static let shared = DeviceDiscoveryService()

    // MARK: - Observable properties (read by SwiftUI on MainActor)

    private(set) var discoveredDevices: [DiscoveredDevice] = []
    private(set) var isScanning: Bool = false
    private(set) var scanProgress: Double = 0
    private(set) var scanPhase: ScanPhase = .idle
    private(set) var lastScanDate: Date?

    enum ScanPhase: String, Sendable {
        case idle = ""
        case arpScan = "Scanning network…"
        case tcpProbe = "Probing ports…"
        case bonjour = "Bonjour discovery…"
        case ssdp = "UPnP discovery…"
        case companion = "Mac companion…"
        case resolving = "Resolving names…"
        case done = "Complete"
    }

    // MARK: - Private scan filter / target types

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

    // MARK: - Private state

    private let accumulator = ScanAccumulator()

    private var scanTask: Task<Void, Never>?

    private let maxConcurrentHosts = 12
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

    // MARK: - Batched UI update helpers

    /// Flush accumulated devices and progress to UI.
    private func flushToMainActor(progress: Double? = nil, phase: ScanPhase? = nil) async {
        let devices = await accumulator.snapshot()
        self.discoveredDevices = devices
        if let progress { self.scanProgress = progress }
        if let phase { self.scanPhase = phase }
    }

    // MARK: - Public API

    func scanNetwork(subnet: String? = nil) async {
        guard !isScanning else { return }

        await accumulator.reset()
        isScanning = true
        scanProgress = 0
        scanPhase = .arpScan
        discoveredDevices = []

        defer {
            isScanning = false
            scanPhase = .idle
            lastScanDate = Date()
        }

        let scanTarget = makeScanTarget(subnet: subnet)

        // If paired with Mac, kick off its scan early (it runs in parallel)
        let macConnection = MacConnectionService.shared
        let macConnected = macConnection.connectionState.isConnected
        if macConnected {
            await macConnection.send(command: CommandPayload(action: .scanDevices))
        }

        // Phase 0: Fire ARP UDP probes and start Bonjour simultaneously
        // (muk: overlap ARP wait with Bonjour and TCP probe start)
        await Self.fireARPProbes(hosts: scanTarget.hosts)

        // Start Bonjour immediately — runs in parallel with ARP + TCP
        let bonjourService = BonjourDiscoveryService()
        bonjourService.startDiscovery()

        // Read ARP cache after 2s delay (overlaps with TCP probes)
        async let arpFuture = Self.readARPCacheAfterDelay()

        scanPhase = .tcpProbe
        scanProgress = 0.05

        // Phase 1: TCP probes run concurrently with ARP cache read.
        // (ji1: skip TCP probes for IPs already discovered by ARP)
        // We read ARP results early and filter out known IPs before probing.
        let totalHosts = scanTarget.hosts.count
        var scannedCount = 0
        var lastFlushedProgress: Double = 0.05
        let concurrencyLimit = maxConcurrentHosts

        if totalHosts > 0 {
            // Collect ARP results as soon as available (runs concurrently)
            let arpResults = await arpFuture
            var arpDiscoveredIPs: Set<String> = []
            for (ip, mac) in arpResults {
                arpDiscoveredIPs.insert(ip)
                await accumulator.upsert(DiscoveredDevice(
                    ipAddress: ip,
                    hostname: nil,
                    vendor: nil,
                    macAddress: mac,
                    latency: nil,
                    discoveredAt: Date(),
                    source: .local
                ))
            }
            await flushToMainActor(progress: 0.10)

            // Filter host list: skip IPs already found by ARP
            let hostsToProbe = arpDiscoveredIPs.isEmpty
                ? scanTarget.hosts
                : scanTarget.hosts.filter { !arpDiscoveredIPs.contains($0) }
            let probeTotal = hostsToProbe.count

            await withTaskGroup(of: DiscoveredDevice?.self) { group in
                var pending = 0
                var hostIterator = hostsToProbe.makeIterator()
                var scanning = true

                while scanning {
                    while pending < concurrencyLimit, let ip = hostIterator.next() {
                        pending += 1
                        group.addTask {
                            await Self.probeHost(ip)
                        }
                    }

                    guard let result = await group.next() else { break }
                    pending -= 1
                    scannedCount += 1

                    let progress = 0.10 + Double(scannedCount) / Double(max(probeTotal, 1)) * 0.55

                    if let device = result {
                        await self.accumulator.upsert(device)
                    }

                    // Throttled flush: every 2% progress change
                    if progress - lastFlushedProgress >= 0.02 {
                        lastFlushedProgress = progress
                        await self.flushToMainActor(progress: progress)
                    }

                    // Check if scan was stopped
                    scanning = self.isScanning
                }
            }
        }

        await flushToMainActor(progress: 0.65, phase: .bonjour)

        // Phase 3: Bonjour post-probe wait + SSDP discovery run in parallel
        let ssdpFilter = scanTarget.filter
        async let ssdpIPs = Self.discoverSSDP()

        // Give Bonjour 5 seconds to catch late-arriving mDNS responses
        try? await Task.sleep(for: .seconds(5))

        // Merge Bonjour-discovered devices
        let bonjourServices = bonjourService.discoveredServices
        await mergeBonjourDevices(bonjourServices, filter: scanTarget.filter)
        bonjourService.stopDiscovery()
        await flushToMainActor(progress: 0.78, phase: .ssdp)

        // Phase 4: Merge SSDP results (already collected in parallel)
        let collectedSSDP = await ssdpIPs
        for ip in collectedSSDP where ssdpFilter.contains(ipAddress: ip) {
            await accumulator.upsert(DiscoveredDevice(
                ipAddress: ip,
                hostname: nil,
                vendor: nil,
                macAddress: nil,
                latency: nil,
                discoveredAt: Date(),
                source: .ssdp
            ))
        }
        await flushToMainActor(progress: 0.84, phase: .companion)

        // Phase 5: Merge Mac companion devices
        let macStillConnected = macConnection.connectionState.isConnected
        if macStillConnected {
            await macConnection.send(command: CommandPayload(action: .refreshDevices))
            try? await Task.sleep(for: .seconds(1))
        }
        await mergeCompanionDevices(filter: scanTarget.filter)
        await flushToMainActor(progress: 0.90, phase: .resolving)

        // Phase 6: Resolve hostnames via reverse DNS for devices that don't have one
        await resolveHostnames()
        await flushToMainActor(progress: 0.98)

        // Final sort and flush
        let sorted = await accumulator.sortedSnapshot()
        discoveredDevices = sorted
        scanProgress = 1.0
        scanPhase = .done
    }

    func stopScan() {
        isScanning = false
        scanTask?.cancel()
    }

    // MARK: - ARP helpers

    /// Fire ARP probes off MainActor to avoid blocking UI.
    private nonisolated static func fireARPProbes(hosts: [String]) async {
        ARPCacheScanner.populateARPCache(hosts: hosts)
    }

    /// Read ARP cache after a delay to allow resolution to complete.
    private nonisolated static func readARPCacheAfterDelay() async -> [(ip: String, mac: String)] {
        try? await Task.sleep(for: .seconds(2))
        return ARPCacheScanner.readARPCache()
    }

    // MARK: - Scan Target Planning

    private nonisolated func makeScanTarget(subnet: String?) -> ScanTarget {
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

    private nonisolated func hostsForSubnetPrefix(_ subnet: String, excluding ipToSkip: String?) -> [String] {
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
    private nonisolated static func discoverSSDP() async -> [String] {
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

        await ConnectionBudget.shared.acquire()
        // vp5: guarantee release even on early return or cancellation
        defer { Task { await ConnectionBudget.shared.release() } }

        let connection = NWConnection(to: endpoint, using: params)

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
            connection.start(queue: probeQueue)
        }

        guard ready else {
            connection.cancel()
            return []
        }

        // Send M-SEARCH
        connection.send(content: messageData, completion: .contentProcessed { _ in })

        // blg: Single receive loop using AsyncStream instead of busy-wait
        let responses = AsyncStream<Data> { continuation in
            func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, _ in
                    if let data {
                        continuation.yield(data)
                    }
                    if isComplete {
                        continuation.finish()
                    } else {
                        receiveNext()
                    }
                }
            }
            continuation.onTermination = { @Sendable _ in
                connection.cancel()
            }
            receiveNext()
        }

        // Collect responses for 3 seconds, then stop
        let collectTask = Task<Set<String>, Never> {
            var ips: Set<String> = []
            for await data in responses {
                if let text = String(data: data, encoding: .utf8),
                   let ip = extractIPFromSSDPResponse(text) {
                    ips.insert(ip)
                }
            }
            return ips
        }

        try? await Task.sleep(for: .seconds(3))
        collectTask.cancel()
        connection.cancel()
        let discoveredIPs = await collectTask.value
        return Array(discoveredIPs)
    }

    /// Resolve hostnames for devices missing one via reverse DNS (PTR) lookup.
    private func resolveHostnames() async {
        let devices = await accumulator.snapshot()
        let devicesNeedingNames = devices.filter { $0.hostname == nil }
        guard !devicesNeedingNames.isEmpty else { return }

        let maxResolve = 20
        await withTaskGroup(of: (String, String?).self) { group in
            var pending = 0
            var iterator = devicesNeedingNames.makeIterator()

            while pending < maxResolve, let device = iterator.next() {
                pending += 1
                group.addTask { [nameResolver] in
                    let name = await nameResolver.resolve(ipAddress: device.ipAddress, bonjourServices: [])
                    return (device.ipAddress, name)
                }
            }

            for await (ip, hostname) in group {
                pending -= 1

                if let hostname {
                    await self.accumulator.upsert(DiscoveredDevice(
                        ipAddress: ip,
                        hostname: hostname,
                        vendor: nil,
                        macAddress: nil,
                        latency: nil,
                        discoveredAt: Date(),
                        source: .local
                    ))
                }

                if let nextDevice = iterator.next() {
                    pending += 1
                    group.addTask { [nameResolver] in
                        let name = await nameResolver.resolve(ipAddress: nextDevice.ipAddress, bonjourServices: [])
                        return (nextDevice.ipAddress, name)
                    }
                }
            }
        }
    }

    /// Merge devices discovered by the paired Mac into accumulated results.
    private func mergeCompanionDevices(filter: ScanFilter) async {
        let macDevices = MacConnectionService.shared.lastDeviceList?.devices
        guard let macDevices else { return }

        for macDevice in macDevices where macDevice.isOnline {
            guard filter.contains(ipAddress: macDevice.ipAddress) else { continue }

            await accumulator.upsert(DiscoveredDevice(
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

    // MARK: - Probe logic

    /// Result of probing a group of ports on a single host.
    private enum ProbeGroupResult: Sendable {
        case reachable(latency: Double)
        case allTimedOut
        case allFailed
    }

    /// Probe a host with staged port groups and return first successful latency.
    private nonisolated static func probeHost(_ ip: String) async -> DiscoveredDevice? {
        let primaryResult = await probePortGroup(
            ip: ip,
            ports: primaryProbePorts,
            timeout: primaryProbeTimeout,
            maxConcurrentPorts: maxConcurrentPortProbes
        )

        switch primaryResult {
        case .reachable(let latency):
            return DiscoveredDevice(ipAddress: ip, latency: latency, discoveredAt: Date())
        case .allTimedOut:
            break  // fall through to try secondary ports
        case .allFailed:
            break
        }

        let secondaryResult = await probePortGroup(
            ip: ip,
            ports: secondaryProbePorts,
            timeout: secondaryProbeTimeout,
            maxConcurrentPorts: maxConcurrentPortProbes
        )

        if case .reachable(let latency) = secondaryResult {
            return DiscoveredDevice(ipAddress: ip, latency: latency, discoveredAt: Date())
        }

        return nil
    }

    /// Per-port probe outcome.
    private enum PortProbeOutcome: Sendable {
        case reachable(latency: Double)
        case refused(latency: Double)
        case timeout
        case failed
    }

    private nonisolated static func probePortGroup(
        ip: String,
        ports: [UInt16],
        timeout: Duration,
        maxConcurrentPorts: Int
    ) async -> ProbeGroupResult {
        guard !ports.isEmpty else { return .allFailed }

        return await withTaskGroup(of: PortProbeOutcome.self, returning: ProbeGroupResult.self) { group in
            var pending = 0
            var iterator = ports.makeIterator()
            var sawRefusal = false
            var sawTimeout = false

            while pending < maxConcurrentPorts, let port = iterator.next() {
                pending += 1
                group.addTask {
                    await probePort(ip: ip, port: port, timeout: timeout)
                }
            }

            while pending > 0 {
                guard let result = await group.next() else { break }
                pending -= 1

                switch result {
                case .reachable(let latency):
                    group.cancelAll()
                    return .reachable(latency: latency)
                case .refused(let latency):
                    sawRefusal = true
                    group.cancelAll()
                    return .reachable(latency: latency)
                case .timeout:
                    sawTimeout = true
                case .failed:
                    break
                }

                if let port = iterator.next() {
                    pending += 1
                    group.addTask {
                        await probePort(ip: ip, port: port, timeout: timeout)
                    }
                }
            }

            if sawTimeout && !sawRefusal {
                return .allTimedOut
            }
            return .allFailed
        }
    }

    private nonisolated static func probePort(ip: String, port: UInt16, timeout: Duration) async -> PortProbeOutcome {
        await ConnectionBudget.shared.acquire()
        defer { Task { await ConnectionBudget.shared.release() } }

        let host = NWEndpoint.Host(ip)
        let endpoint = NWEndpoint.hostPort(host: host, port: NWEndpoint.Port(rawValue: port)!)
        let params = NWParameters.tcp
        params.requiredInterfaceType = .wifi

        let connection = NWConnection(to: endpoint, using: params)

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<PortProbeOutcome, Never>) in
            let resumed = ResumeState()

            let timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                guard await resumed.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: .timeout)
            }

            let start = Date()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()
                        continuation.resume(returning: .reachable(latency: elapsed))
                    }
                case .failed(let error):
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()

                        if case NWError.posix(let code) = error, code == .ECONNREFUSED {
                            continuation.resume(returning: .refused(latency: elapsed))
                        } else {
                            continuation.resume(returning: .failed)
                        }
                    }
                case .cancelled:
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()
                        continuation.resume(returning: .failed)
                    }
                default:
                    break
                }
            }

            connection.start(queue: probeQueue)
        }

        connection.cancel()
        return result
    }

    // MARK: - Bonjour merge

    /// Merge devices found via Bonjour service browsing into the accumulator.
    private func mergeBonjourDevices(_ services: [BonjourService], filter: ScanFilter) async {
        let uniqueServices = uniqueBonjourServices(from: services)
        let capped = Array(uniqueServices.prefix(maxBonjourServiceResolves))
        guard !capped.isEmpty else { return }

        await withTaskGroup(of: DiscoveredDevice?.self) { group in
            var pending = 0
            var iterator = capped.makeIterator()

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
                    await self.accumulator.upsert(device)
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
        await ConnectionBudget.shared.acquire()
        // vp5: guarantee release even on early return or cancellation
        defer { Task { await ConnectionBudget.shared.release() } }

        let endpoint = NWEndpoint.service(
            name: service.name,
            type: service.type,
            domain: service.domain,
            interface: nil
        )

        let params = NWParameters.tcp

        let connection = NWConnection(to: endpoint, using: params)

        let result: String? = await withCheckedContinuation { continuation in
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

            connection.start(queue: probeQueue)
        }

        connection.cancel()
        return result
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

    // MARK: - String helpers

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

    private nonisolated func uniqueBonjourServices(from services: [BonjourService]) -> [BonjourService] {
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
