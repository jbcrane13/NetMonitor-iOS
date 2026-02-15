import Foundation
import Network
import SwiftData
import NetworkScanKit

@MainActor
@Observable
final class DeviceDiscoveryService {
    /// Shared instance for app-wide use. Prefer injecting via init for testability.
    static let shared = DeviceDiscoveryService()

    // MARK: - Observable properties (read by SwiftUI on MainActor)

    private(set) var discoveredDevices: [DiscoveredDevice] = []
    private(set) var isScanning: Bool = false
    private(set) var scanProgress: Double = 0
    private(set) var scanPhase: ScanDisplayPhase = .idle
    private(set) var lastScanDate: Date?

    enum ScanDisplayPhase: String, Sendable {
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

    private let engine = ScanEngine()

    private var scanTask: Task<Void, Never>?

    private let maxHostsPerScan = 1024

    // MARK: - Batched UI update helpers

    /// Flush accumulated devices and progress to UI.
    private func flushToMainActor(progress: Double? = nil, phase: ScanDisplayPhase? = nil) async {
        let devices = await engine.accumulator.snapshot()
        self.discoveredDevices = devices
        if let progress { self.scanProgress = progress }
        if let phase { self.scanPhase = phase }
    }

    // MARK: - Public API

    func scanNetwork(subnet: String? = nil) async {
        guard !isScanning else { return }

        await engine.reset()
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

        // Start Bonjour discovery early — runs during ARP + TCP phases
        let bonjourService = BonjourDiscoveryService()
        bonjourService.startDiscovery()

        // Build ScanContext
        let filter = scanTarget.filter
        let context = ScanContext(
            hosts: scanTarget.hosts,
            subnetFilter: { filter.contains(ipAddress: $0) },
            localIP: NetworkUtilities.detectLocalIPAddress()
        )

        // Build pipeline with Bonjour service provider
        let bonjourPhase = BonjourScanPhase(serviceProvider: {
            await MainActor.run {
                bonjourService.discoveredServices.map {
                    BonjourServiceInfo(name: $0.name, type: $0.type, domain: $0.domain)
                }
            }
        }, stopProvider: {
            await MainActor.run { bonjourService.stopDiscovery() }
        })

        let pipeline = ScanPipeline(steps: [
            ScanPipeline.Step(phases: [ARPScanPhase(), bonjourPhase], concurrent: true),
            ScanPipeline.Step(phases: [TCPProbeScanPhase(), SSDPScanPhase()], concurrent: true),
            ScanPipeline.Step(phases: [ReverseDNSScanPhase()], concurrent: false),
        ])

        // Run the scan engine
        let engineRef = engine
        _ = await engineRef.scan(pipeline: pipeline, context: context) { [weak self] progress, phaseName in
            let snapshot = await engineRef.accumulator.snapshot()
            await MainActor.run {
                guard let self else { return }
                self.scanProgress = progress
                self.discoveredDevices = snapshot
                if let phase = ScanDisplayPhase(rawValue: phaseName) {
                    self.scanPhase = phase
                }
            }
        }

        // Phase: Mac companion merge
        scanPhase = .companion
        scanProgress = 0.90

        let macStillConnected = macConnection.connectionState.isConnected
        if macStillConnected {
            await macConnection.send(command: CommandPayload(action: .refreshDevices))
            try? await Task.sleep(for: .seconds(1))
        }
        await mergeCompanionDevices(filter: scanTarget.filter)
        await flushToMainActor(progress: 0.95)

        // Final sort and flush
        let sorted = await engine.accumulator.sortedSnapshot()
        discoveredDevices = sorted
        scanProgress = 1.0
        scanPhase = .done
    }

    func stopScan() {
        isScanning = false
        scanTask?.cancel()
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

    // MARK: - Mac Companion Merge

    /// Merge devices discovered by the paired Mac into accumulated results.
    private func mergeCompanionDevices(filter: ScanFilter) async {
        let macDevices = MacConnectionService.shared.lastDeviceList?.devices
        guard let macDevices else { return }

        for macDevice in macDevices where macDevice.isOnline {
            guard filter.contains(ipAddress: macDevice.ipAddress) else { continue }

            await engine.accumulator.upsert(DiscoveredDevice(
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
}
