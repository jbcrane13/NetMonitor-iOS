import Foundation
import Network

@MainActor
@Observable
final class BonjourDiscoveryService {
    private(set) var discoveredServices: [BonjourService] = []
    private(set) var isDiscovering: Bool = false

    private var browser: NWBrowser?
    private var typeBrowsers: [NWBrowser] = []
    private let queue = DispatchQueue(label: "com.netmonitor.bonjour")
    
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
    
    func startDiscovery(serviceType: String? = nil) {
        stopDiscovery()
        
        isDiscovering = true
        discoveredServices = []
        
        let descriptor: NWBrowser.Descriptor
        if let type = serviceType {
            descriptor = .bonjour(type: type, domain: "local.")
        } else {
            descriptor = .bonjour(type: "_services._dns-sd._udp", domain: "local.")
        }
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        browser = NWBrowser(for: descriptor, using: parameters)
        
        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                switch state {
                case .failed(let error):
                    print("Browser failed: \(error)")
                    self?.isDiscovering = false
                case .cancelled:
                    self?.isDiscovering = false
                default:
                    break
                }
            }
        }
        
        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                self?.handleResults(results)
            }
        }
        
        browser?.start(queue: queue)

        if serviceType == nil {
            for type in commonServiceTypes {
                browseServiceType(type)
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 10) { [weak self] in
                Task { @MainActor [weak self] in
                    for typeBrowser in self?.typeBrowsers ?? [] {
                        typeBrowser.cancel()
                    }
                    self?.typeBrowsers.removeAll()
                }
            }
        }
    }
    
    func stopDiscovery() {
        browser?.cancel()
        browser = nil

        for typeBrowser in typeBrowsers {
            typeBrowser.cancel()
        }
        typeBrowsers.removeAll()

        isDiscovering = false
    }
    
    private func browseServiceType(_ type: String) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: type, domain: "local.")
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let typeBrowser = NWBrowser(for: descriptor, using: parameters)

        typeBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                self?.handleResults(results)
            }
        }

        typeBrowser.start(queue: queue)
        typeBrowsers.append(typeBrowser)
    }
    
    private func handleResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case let .service(name, type, domain, _) = result.endpoint {
                let service = BonjourService(
                    name: name,
                    type: type,
                    domain: domain
                )
                
                if !discoveredServices.contains(where: { $0.name == name && $0.type == type }) {
                    discoveredServices.append(service)
                }
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
