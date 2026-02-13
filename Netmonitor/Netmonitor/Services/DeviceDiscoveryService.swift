import Foundation
import Network
import SwiftData

@Observable
final class DeviceDiscoveryService: @unchecked Sendable {
    @MainActor static let shared = DeviceDiscoveryService()

    @MainActor
    private init() {}

    // MARK: - Observable properties (read by SwiftUI on MainActor)

    @MainActor private(set) var discoveredDevices: [DiscoveredDevice] = []
    @MainActor private(set) var isScanning: Bool = false
    @MainActor private(set) var scanProgress: Double = 0
    @MainActor private(set) var scanPhase: ScanPhase = .idle
    @MainActor private(set) var lastScanDate: Date?

    enum ScanPhase: String, Sendable {
        case idle = ""
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

    /// Working buffer for device accumulation during scan (accessed off MainActor).
    private var pendingDevices: [DiscoveredDevice] = []
    private var pendingIndexByIP: [String: Int] = [:]

    private var scanTask: Task<Void, Never>?

    private let maxConcurrentHosts = 24
    private let maxHostsPerScan = 1024
    private let maxBonjourServiceResolves = 100
    private let maxBonjourResolveConcurrency = 8

    private let nameResolver = DeviceNameResolver()

    /// Last progress value that was flushed to MainActor, used for 2% throttling.
    private var lastFlushedProgress: Double = 0

    private nonisolated static let probeQueue = DispatchQueue(label: "com.netmonitor.probe", qos: .userInitiated, attributes: .concurrent)

    /// Stage 1 ports: high-yield services for most LAN devices.
    private nonisolated static let primaryProbePorts: [UInt16] = [80, 443, 22, 445]

    /// Stage 2 ports: broaden coverage for IoT, printers, media devices, and Apple services.
    private nonisolated static let secondaryProbePorts: [UInt16] = [7000, 8080, 8443, 62078, 5353, 9100, 1883, 554, 548]

    private nonisolated static let maxConcurrentPortProbes = 3
    private nonisolated static let primaryProbeTimeout: Duration = .milliseconds(700)
    private nonisolated static let secondaryProbeTimeout: Duration = .milliseconds(1200)

    // MARK: - Batched UI update helpers

    /// Flush pending devices and progress to MainActor.
    private func flushToMainActor(progress: Double? = nil, phase: ScanPhase? = nil) async {
        let devices = pendingDevices
        let indexByIP = pendingIndexByIP
        let prog = progress
        let ph = phase
        await MainActor.run {
            self.discoveredDevices = devices
            if let prog { self.scanProgress = prog }
            if let ph { self.scanPhase = ph }
            // Keep private index in sync — not strictly needed on MainActor
            // but ensures consistency if someone reads discoveredDevices.count
            _ = indexByIP  // suppress unused warning
        }
    }

    /// Conditionally flush progress if it changed by >= 2% since last flush.
    private func throttledProgressFlush(_ progress: Double) async {
        guard progress - lastFlushedProgress >= 0.02 else { return }
        lastFlushedProgress = progress
        let devices = pendingDevices
        await MainActor.run {
            self.discoveredDevices = devices
            self.scanProgress = progress
        }
    }

    // MARK: - Public API

    func scanNetwork(subnet: String? = nil) async {
        let alreadyScanning = await MainActor.run { isScanning }
        guard !alreadyScanning else { return }

        // Reset working buffer
        pendingDevices = []
        pendingIndexByIP = [:]
        lastFlushedProgress = 0

        await MainActor.run {
            self.isScanning = true
            self.scanProgress = 0
            self.scanPhase = .tcpProbe
            self.discoveredDevices = []
        }

        defer {
            Task { @MainActor in
                self.isScanning = false
                self.scanPhase = .idle
                self.lastScanDate = Date()
            }
        }

        let scanTarget = makeScanTarget(subnet: subnet)

        // If paired with Mac, kick off its scan early (it runs in parallel)
        let macConnection = await MainActor.run { MacConnectionService.shared }
        let macConnected = await MainActor.run { macConnection.connectionState.isConnected }
        if macConnected {
            await macConnection.send(command: CommandPayload(action: .scanDevices))
        }

        // Phase 1: Bonjour discovery — start early, let it accumulate during TCP probes
        let bonjourService = await MainActor.run { BonjourDiscoveryService() }
        await MainActor.run { bonjourService.startDiscovery() }

        // Phase 2: TCP probes over computed host targets
        let totalHosts = scanTarget.hosts.count
        var scannedCount = 0
        var localProgress: Double = 0

        if totalHosts > 0 {
            await withTaskGroup(of: DiscoveredDevice?.self) { group in
                var pending = 0
                var hostIterator = scanTarget.hosts.makeIterator()
                var scanning = true

                while scanning {
                    while pending < maxConcurrentHosts, let ip = hostIterator.next() {
                        pending += 1
                        group.addTask {
                            await Self.probeHost(ip)
                        }
                    }

                    guard let result = await group.next() else { break }
                    pending -= 1
                    scannedCount += 1

                    // TCP probes are 0–70% of progress
                    localProgress = Double(scannedCount) / Double(totalHosts) * 0.70

                    if let device = result {
                        upsertPendingDevice(device)
                    }

                    // Throttled flush: every 2% progress change
                    await throttledProgressFlush(localProgress)

                    // Check if scan was stopped
                    scanning = await MainActor.run { self.isScanning }
                }
            }
        } else {
            localProgress = 0.70
        }

        // Flush all TCP probe results
        await flushToMainActor(progress: 0.70, phase: .bonjour)

        // Phase 3: Bonjour post-probe wait + SSDP discovery run in parallel.
        // Start SSDP collection immediately so it overlaps with the Bonjour wait.
        let ssdpFilter = scanTarget.filter
        async let ssdpIPs = discoverSSDP()

        // Give Bonjour 5 seconds to catch late-arriving mDNS responses
        try? await Task.sleep(for: .seconds(5))

        // Merge Bonjour-discovered devices
        let bonjourServices = await MainActor.run { bonjourService.discoveredServices }
        await mergeBonjourDevices(bonjourServices, filter: scanTarget.filter)
        await MainActor.run { bonjourService.stopDiscovery() }
        await flushToMainActor(progress: 0.78, phase: .ssdp)

        // Phase 4: Merge SSDP results (already collected in parallel)
        let collectedSSDP = await ssdpIPs
        for ip in collectedSSDP where ssdpFilter.contains(ipAddress: ip) {
            upsertPendingDevice(DiscoveredDevice(
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
        let macStillConnected = await MainActor.run { macConnection.connectionState.isConnected }
        if macStillConnected {
            await macConnection.send(command: CommandPayload(action: .refreshDevices))
            try? await Task.sleep(for: .seconds(1))
        }
        await mergeCompanionDevices(filter: scanTarget.filter)
        await flushToMainActor(progress: 0.90, phase: .resolving)

        // Phase 6: Resolve hostnames via reverse DNS for devices that don't have one.
        await resolveHostnames()
        await flushToMainActor(progress: 0.98)

        pendingDevices.sort { $0.ipAddress.ipSortKey < $1.ipAddress.ipSortKey }
        rebuildPendingIndexByIP()

        await flushToMainActor(progress: 1.0, phase: .done)
    }

    @MainActor
    func stopScan() {
        isScanning = false
        scanTask?.cancel()
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
    private nonisolated func discoverSSDP() async -> [String] {
        let multicastGroup = "239.255.255.250"
        let multicastPort: UInt16 = 1900
        let searchMessage = [
            "M-SEARCH * HTTP/1.1",
            "HOST: 239.255.255.250:1900",
            "MAN: \"ssdp:discover\"",
            "MX: 5",
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
        let connection = NWConnection(to: endpoint, using: params)
        defer {
            connection.cancel()
            Task { await ConnectionBudget.shared.release() }
        }

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

        // Collect responses for 5 seconds.
        var discoveredIPs: Set<String> = []
        let deadline = Date().addingTimeInterval(5.0)

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

    /// Resolve hostnames for devices missing one via reverse DNS (PTR) lookup.
    private func resolveHostnames() async {
        let devicesNeedingNames = pendingDevices.enumerated().filter { $0.element.hostname == nil }
        guard !devicesNeedingNames.isEmpty else { return }

        let maxResolve = 10
        await withTaskGroup(of: (Int, String?).self) { group in
            var pending = 0
            var iterator = devicesNeedingNames.makeIterator()

            while pending < maxResolve, let (index, device) = iterator.next() {
                pending += 1
                group.addTask { [nameResolver] in
                    let name = await nameResolver.resolve(ipAddress: device.ipAddress, bonjourServices: [])
                    return (index, name)
                }
            }

            for await (index, hostname) in group {
                pending -= 1

                if let hostname, index < pendingDevices.count {
                    let existing = pendingDevices[index]
                    pendingDevices[index] = DiscoveredDevice(
                        ipAddress: existing.ipAddress,
                        hostname: hostname,
                        vendor: existing.vendor,
                        macAddress: existing.macAddress,
                        latency: existing.latency,
                        discoveredAt: existing.discoveredAt,
                        source: existing.source
                    )
                }

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

    /// Merge devices discovered by the paired Mac into pending results.
    private func mergeCompanionDevices(filter: ScanFilter) async {
        let macDevices = await MainActor.run { MacConnectionService.shared.lastDeviceList?.devices }
        guard let macDevices else { return }

        for macDevice in macDevices where macDevice.isOnline {
            guard filter.contains(ipAddress: macDevice.ipAddress) else { continue }

            upsertPendingDevice(DiscoveredDevice(
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
            return nil
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
        defer { connection.cancel() }

        return await withCheckedContinuation { (continuation: CheckedContinuation<PortProbeOutcome, Never>) in
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
    }

    // MARK: - Bonjour merge

    /// Merge devices found via Bonjour service browsing into the pending device list.
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
                    upsertPendingDevice(device)
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
        defer { Task { await ConnectionBudget.shared.release() } }

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

            connection.start(queue: probeQueue)
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

    // MARK: - Pending device dedup / merge helpers

    private func upsertPendingDevice(_ device: DiscoveredDevice) {
        if let existingIndex = pendingIndexByIP[device.ipAddress] {
            let existing = pendingDevices[existingIndex]
            pendingDevices[existingIndex] = mergedDevice(existing: existing, incoming: device)
        } else {
            pendingIndexByIP[device.ipAddress] = pendingDevices.count
            pendingDevices.append(device)
        }
    }

    private func rebuildPendingIndexByIP() {
        pendingIndexByIP = [:]
        pendingIndexByIP.reserveCapacity(pendingDevices.count)

        for (index, device) in pendingDevices.enumerated() {
            pendingIndexByIP[device.ipAddress] = index
        }
    }

    private nonisolated func mergedDevice(existing: DiscoveredDevice, incoming: DiscoveredDevice) -> DiscoveredDevice {
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
