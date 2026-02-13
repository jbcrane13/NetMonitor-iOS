import Foundation
import Network

@MainActor
@Observable
final class BonjourDiscoveryService {
    private(set) var discoveredServices: [BonjourService] = []
    private(set) var isDiscovering: Bool = false

    private var typeBrowsers: [NWBrowser] = []
    private let queue = DispatchQueue(label: "com.netmonitor.bonjour")
    private var serviceContinuation: AsyncStream<BonjourService>.Continuation?
    
    private let commonServiceTypes = [
        "_http._tcp",
        "_https._tcp",
        "_ssh._tcp",
        "_smb._tcp",
        "_afpovertcp._tcp",
        "_printer._tcp",
        "_ipp._tcp",
        "_airplay._tcp",
        "_raop._tcp",
        "_googlecast._tcp",
        "_spotify-connect._tcp",
        "_homekit._tcp",
        "_hap._tcp"
    ]

    /// Returns an AsyncStream that yields newly discovered services as they are found.
    func discoveryStream(serviceType: String? = nil) -> AsyncStream<BonjourService> {
        stopDiscovery()

        return AsyncStream { continuation in
            self.serviceContinuation = continuation
            self.isDiscovering = true
            self.discoveredServices = []

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.stopDiscovery()
                }
            }

            self.startBrowsing(serviceType: serviceType)
        }
    }
    
    func startDiscovery(serviceType: String? = nil) {
        stopDiscovery()
        
        isDiscovering = true
        discoveredServices = []

        startBrowsing(serviceType: serviceType)
    }

    private func startBrowsing(serviceType: String? = nil) {
        if let type = serviceType {
            browseServiceType(type)
        } else {
            for type in commonServiceTypes {
                browseServiceType(type)
            }

            // Timeout cleanup for type browsers
            DispatchQueue.global().asyncAfter(deadline: .now() + 30) { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isDiscovering else { return }
                    for typeBrowser in self.typeBrowsers {
                        typeBrowser.cancel()
                    }
                    self.typeBrowsers.removeAll()
                }
            }
        }
    }
    
    func stopDiscovery() {
        for typeBrowser in typeBrowsers {
            typeBrowser.cancel()
        }
        typeBrowsers.removeAll()

        serviceContinuation?.finish()
        serviceContinuation = nil
        isDiscovering = false
    }
    
    private func browseServiceType(_ type: String) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: type, domain: "local.")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let typeBrowser = NWBrowser(for: descriptor, using: parameters)

        typeBrowser.stateUpdateHandler = { state in
            Task { @MainActor in
                if case .failed(let error) = state {
                    print("Browser failed for \(type): \(error)")
                }
            }
        }

        typeBrowser.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.handleChanges(changes)
            }
        }

        typeBrowser.start(queue: queue)
        typeBrowsers.append(typeBrowser)
    }
    
    private func handleChanges(_ changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                if case let .service(name, type, domain, _) = result.endpoint {
                    let service = BonjourService(
                        name: name,
                        type: type,
                        domain: domain
                    )
                    if !discoveredServices.contains(where: { $0.name == name && $0.type == type }) {
                        discoveredServices.append(service)
                        serviceContinuation?.yield(service)
                    }
                }
            case .removed(let result):
                if case let .service(name, type, _, _) = result.endpoint {
                    discoveredServices.removeAll { $0.name == name && $0.type == type }
                }
            default:
                break
            }
        }
    }
    
    func resolveService(_ service: BonjourService) async -> BonjourService? {
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.service(
                name: service.name,
                type: service.type,
                domain: service.domain,
                interface: nil
            )

            let connection = NWConnection(to: endpoint, using: .tcp)
            let resumeState = ResumeState()

            connection.stateUpdateHandler = { state in
                Task {
                    switch state {
                    case .ready:
                        guard await !resumeState.hasResumed else { return }
                        await resumeState.setResumed()

                        if let innerEndpoint = connection.currentPath?.remoteEndpoint,
                           case let .hostPort(host, port) = innerEndpoint {
                            let resolved = BonjourService(
                                name: service.name,
                                type: service.type,
                                domain: service.domain,
                                hostName: "\(host)",
                                port: Int(port.rawValue)
                            )
                            connection.cancel()
                            continuation.resume(returning: resolved)
                        } else {
                            connection.cancel()
                            continuation.resume(returning: nil)
                        }
                    case .failed, .cancelled:
                        guard await !resumeState.hasResumed else { return }
                        await resumeState.setResumed()
                        continuation.resume(returning: nil)
                    default:
                        break
                    }
                }
            }

            connection.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                Task {
                    guard await !resumeState.hasResumed else { return }
                    await resumeState.setResumed()
                    connection.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
