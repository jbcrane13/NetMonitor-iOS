import Foundation
import Network

@Observable
final class BonjourDiscoveryService: @unchecked Sendable {
    @MainActor
    init() {}

    // MARK: - Observable properties (read by SwiftUI on MainActor)

    @MainActor private(set) var discoveredServices: [BonjourService] = []
    @MainActor private(set) var isDiscovering: Bool = false

    // MARK: - Private state

    private var typeBrowsers: [NWBrowser] = []
    private let queue = DispatchQueue(label: "com.netmonitor.bonjour")
    private var serviceContinuation: AsyncStream<BonjourService>.Continuation?

    /// Private buffer for accumulating services off MainActor.
    private var pendingServices: [BonjourService] = []

    /// Coalescing task that batches MainActor flushes.
    private var flushTask: Task<Void, Never>?

    /// Tier 1: highest-yield service types — browsed immediately.
    private let tier1ServiceTypes = [
        "_http._tcp",
        "_https._tcp",
        "_smb._tcp",
        "_ssh._tcp",
        "_airplay._tcp",
        "_raop._tcp",
    ]

    /// Tier 2: remaining types — browsed after a 5-second delay to reduce
    /// initial resource pressure during the critical scan window.
    private let tier2ServiceTypes = [
        "_afpovertcp._tcp",
        "_printer._tcp",
        "_ipp._tcp",
        "_homekit._tcp",
        "_hap._tcp",
        "_companion-link._tcp",
        "_apple-mobdev2._tcp",
        "_device-info._tcp",
        "_googlecast._tcp",
        "_spotify-connect._tcp",
        "_sonos._tcp",
        "_workstation._tcp",
    ]

    // MARK: - Public API

    /// Returns an AsyncStream that yields newly discovered services as they are found.
    @MainActor
    func discoveryStream(serviceType: String? = nil) -> AsyncStream<BonjourService> {
        stopDiscovery()

        return AsyncStream { continuation in
            self.serviceContinuation = continuation
            self.isDiscovering = true
            self.discoveredServices = []
            self.pendingServices = []

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.stopDiscovery()
                }
            }

            self.startBrowsing(serviceType: serviceType)
        }
    }

    @MainActor
    func startDiscovery(serviceType: String? = nil) {
        stopDiscovery()

        isDiscovering = true
        discoveredServices = []
        pendingServices = []

        startBrowsing(serviceType: serviceType)
    }

    /// Task for auto-cleanup of browsers after timeout
    private var browserCleanupTask: Task<Void, Never>?

    /// Task that starts tier-2 browsers after a delay.
    private var tier2Task: Task<Void, Never>?

    private func startBrowsing(serviceType: String? = nil) {
        if let type = serviceType {
            browseServiceType(type)
        } else {
            // Tier 1: browse highest-yield types immediately
            for type in tier1ServiceTypes {
                browseServiceType(type)
            }

            // Tier 2: browse remaining types after 5-second delay
            tier2Task?.cancel()
            tier2Task = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled, let self else { return }
                for type in self.tier2ServiceTypes {
                    self.browseServiceType(type)
                }
            }

            // Timeout cleanup for type browsers
            browserCleanupTask?.cancel()
            browserCleanupTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                await self.cleanupBrowsersIfDiscovering()
            }
        }
    }

    @MainActor
    func stopDiscovery() {
        tier2Task?.cancel()
        tier2Task = nil
        browserCleanupTask?.cancel()
        browserCleanupTask = nil
        flushTask?.cancel()
        flushTask = nil

        for typeBrowser in typeBrowsers {
            typeBrowser.cancel()
        }
        typeBrowsers.removeAll()

        serviceContinuation?.finish()
        serviceContinuation = nil
        isDiscovering = false
    }

    @MainActor
    private func cleanupBrowsersIfDiscovering() {
        guard isDiscovering else { return }
        for typeBrowser in typeBrowsers {
            typeBrowser.cancel()
        }
        typeBrowsers.removeAll()
    }

    @MainActor
    private func flushDiscoveredServices(_ services: [BonjourService]) {
        discoveredServices = services
    }

    private func browseServiceType(_ type: String) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: type, domain: "local.")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let typeBrowser = NWBrowser(for: descriptor, using: parameters)

        typeBrowser.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                print("Browser failed for \(type): \(error)")
            }
        }

        typeBrowser.browseResultsChangedHandler = { [weak self] _, changes in
            self?.handleChangesOffMainActor(changes)
        }

        typeBrowser.start(queue: queue)
        typeBrowsers.append(typeBrowser)
    }

    // MARK: - Batched change handling

    /// Handle browser changes off MainActor — accumulate in pending buffer
    /// and schedule a coalesced flush.
    private func handleChangesOffMainActor(_ changes: Set<NWBrowser.Result.Change>) {
        var didChange = false

        for change in changes {
            switch change {
            case .added(let result):
                if case let .service(name, type, domain, _) = result.endpoint {
                    let service = BonjourService(
                        name: name,
                        type: type,
                        domain: domain
                    )
                    if !pendingServices.contains(where: { $0.name == name && $0.type == type }) {
                        pendingServices.append(service)
                        serviceContinuation?.yield(service)
                        didChange = true
                    }
                }
            case .removed(let result):
                if case let .service(name, type, _, _) = result.endpoint {
                    if let idx = pendingServices.firstIndex(where: { $0.name == name && $0.type == type }) {
                        pendingServices.remove(at: idx)
                        didChange = true
                    }
                }
            default:
                break
            }
        }

        if didChange {
            scheduleFlush()
        }
    }

    /// Schedule a coalesced flush to MainActor (debounced at 0.3s).
    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            let latest = self.pendingServices
            await self.flushDiscoveredServices(latest)
            self.flushTask = nil
        }
    }

    // MARK: - Service resolution

    func resolveService(_ service: BonjourService) async -> BonjourService? {
        await ConnectionBudget.shared.acquire()
        defer { Task { await ConnectionBudget.shared.release() } }

        let endpoint = NWEndpoint.service(
            name: service.name,
            type: service.type,
            domain: service.domain,
            interface: nil
        )

        let connection = NWConnection(to: endpoint, using: .tcp)
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
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()

                        if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                           case let .hostPort(host, port) = innerEndpoint {
                            let hostText = "\(host)"
                            let normalizedHost = Self.normalizeHostName(hostText)
                            let addresses = Self.isIPv4Address(normalizedHost) ? [normalizedHost] : []
                            let resolved = BonjourService(
                                name: service.name,
                                type: service.type,
                                domain: service.domain,
                                hostName: hostText,
                                port: Int(port.rawValue),
                                addresses: addresses
                            )
                            connection.cancel()
                            continuation.resume(returning: resolved)
                        } else {
                            connection.cancel()
                            continuation.resume(returning: nil)
                        }
                    }
                case .failed, .cancelled, .waiting:
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

            connection.start(queue: .global())
        }
    }

    private nonisolated static func normalizeHostName(_ host: String) -> String {
        host.split(separator: "%", maxSplits: 1).first.map(String.init) ?? host
    }

    private nonisolated static func isIPv4Address(_ value: String) -> Bool {
        let components = value.split(separator: ".")
        guard components.count == 4 else { return false }
        return components.allSatisfy { UInt8($0) != nil }
    }
}
