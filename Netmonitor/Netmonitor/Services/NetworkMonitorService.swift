import Foundation
import Network
import Combine

@MainActor
@Observable
final class NetworkMonitorService {

    // MARK: - Shared Instance

    /// Single shared monitor so every consumer reads the same, up-to-date
    /// connectivity state.  Previous per-ViewModel instantiation caused a race
    /// where the first render saw `isConnected == false` before the async
    /// NWPathMonitor callback could fire — producing the "No Connection" flash.
    static let shared = NetworkMonitorService()

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

        let newMonitor = NWPathMonitor()
        newMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.updatePath(path)
            }
        }
        newMonitor.start(queue: queue)
        monitor = newMonitor

        // Seed initial state synchronously from the monitor's currentPath so
        // the very first SwiftUI render sees the real connectivity instead of
        // the default `false` / `.none`.
        updatePath(newMonitor.currentPath)
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
