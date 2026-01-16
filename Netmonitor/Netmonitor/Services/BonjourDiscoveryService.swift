import Foundation
import Network

@MainActor
@Observable
final class BonjourDiscoveryService {
    private(set) var discoveredServices: [BonjourService] = []
    private(set) var isDiscovering: Bool = false
    
    private var browser: NWBrowser?
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
        }
    }
    
    func stopDiscovery() {
        browser?.cancel()
        browser = nil
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
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            typeBrowser.cancel()
        }
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
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
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
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                connection.cancel()
            }
        }
    }
}
