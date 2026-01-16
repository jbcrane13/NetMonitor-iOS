import Foundation
import Network
import Combine

@MainActor
@Observable
final class NetworkMonitorService {
    private(set) var isConnected: Bool = false
    private(set) var connectionType: ConnectionType = .none
    private(set) var isExpensive: Bool = false
    private(set) var isConstrained: Bool = false
    private(set) var interfaceName: String?
    
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.netmonitor.networkmonitor")
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        guard monitor == nil else { return }
        
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.updatePath(path)
            }
        }
        monitor?.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }
    
    private func updatePath(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .none
        }
        
        interfaceName = path.availableInterfaces.first?.name
    }
    
    var statusText: String {
        guard isConnected else { return "No Connection" }
        return connectionType.displayName
    }
}
