import Foundation
import Network

@MainActor
@Observable
final class GatewayService {
    private(set) var gateway: GatewayInfo?
    private(set) var isLoading: Bool = false
    private(set) var lastError: String?
    
    func detectGateway() async {
        isLoading = true
        lastError = nil
        
        defer { isLoading = false }
        
        guard let gatewayIP = getDefaultGateway() else {
            lastError = "Could not detect gateway"
            gateway = nil
            return
        }
        
        let latency = await measureLatency(to: gatewayIP)
        
        gateway = GatewayInfo(
            ipAddress: gatewayIP,
            macAddress: nil,
            vendor: nil,
            latency: latency
        )
    }
    
    private func getDefaultGateway() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }
        
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, NI_NUMERICHOST)
                    
                    let ipAddress = String(cString: hostname)
                    let components = ipAddress.split(separator: ".")
                    if components.count == 4 {
                        return "\(components[0]).\(components[1]).\(components[2]).1"
                    }
                }
            }
        }
        return nil
    }
    
    private func measureLatency(to host: String) async -> Double? {
        let start = Date()
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: 80) ?? .http
        )
        
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let latency = Date().timeIntervalSince(start) * 1000
                    connection.cancel()
                    continuation.resume(returning: latency)
                case .failed, .cancelled:
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if connection.state != .ready {
                    connection.cancel()
                }
            }
        }
    }
}
