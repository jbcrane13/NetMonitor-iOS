import Foundation
import Network
import SwiftData

@MainActor
@Observable
final class DeviceDiscoveryService {
    private(set) var discoveredDevices: [DiscoveredDevice] = []
    private(set) var isScanning: Bool = false
    private(set) var scanProgress: Double = 0
    private(set) var lastScanDate: Date?
    
    private var scanTask: Task<Void, Never>?
    private let maxConcurrent = 20
    
    func scanNetwork(subnet: String? = nil) async {
        guard !isScanning else { return }
        
        isScanning = true
        scanProgress = 0
        discoveredDevices = []
        
        defer {
            isScanning = false
            lastScanDate = Date()
        }
        
        let baseIP = subnet ?? detectSubnet() ?? "192.168.1"
        let totalHosts = 254
        var scannedCount = 0
        
        await withTaskGroup(of: DiscoveredDevice?.self) { group in
            var pending = 0
            var hostIterator = (1...254).makeIterator()
            
            while isScanning {
                while pending < maxConcurrent, let host = hostIterator.next() {
                    pending += 1
                    let ip = "\(baseIP).\(host)"
                    
                    group.addTask { [weak self] in
                        await self?.probeHost(ip)
                    }
                }
                
                guard let result = await group.next() else { break }
                pending -= 1
                scannedCount += 1
                scanProgress = Double(scannedCount) / Double(totalHosts)
                
                if let device = result {
                    discoveredDevices.append(device)
                }
            }
        }
        
        discoveredDevices.sort { $0.ipAddress.ipSortKey < $1.ipAddress.ipSortKey }
    }
    
    func stopScan() {
        isScanning = false
        scanTask?.cancel()
    }
    
    private nonisolated func probeHost(_ ip: String) async -> DiscoveredDevice? {
        let start = Date()
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(ip),
            port: .http
        )
        
        let resumeState = ResumeState()
        
        let isReachable = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let connection = NWConnection(to: endpoint, using: .tcp)
            
            connection.stateUpdateHandler = { state in
                Task {
                    guard await !resumeState.hasResumed else { return }
                    
                    switch state {
                    case .ready:
                        await resumeState.setResumed()
                        connection.cancel()
                        continuation.resume(returning: true)
                    case .failed, .cancelled:
                        await resumeState.setResumed()
                        continuation.resume(returning: false)
                    default:
                        break
                    }
                }
            }
            
            connection.start(queue: .global())
            
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard await !resumeState.hasResumed else { return }
                await resumeState.setResumed()
                connection.cancel()
                continuation.resume(returning: false)
            }
        }
        
        guard isReachable else { return nil }
        
        let latency = Date().timeIntervalSince(start) * 1000
        
        return DiscoveredDevice(
            ipAddress: ip,
            latency: latency,
            discoveredAt: Date()
        )
    }
    
    private func detectSubnet() -> String? {
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
                        return "\(components[0]).\(components[1]).\(components[2])"
                    }
                }
            }
        }
        return nil
    }
}

struct DiscoveredDevice: Identifiable, Sendable {
    let id = UUID()
    let ipAddress: String
    let latency: Double
    let discoveredAt: Date
    
    var latencyText: String {
        if latency < 1 {
            return "<1 ms"
        }
        return String(format: "%.0f ms", latency)
    }
}

private extension String {
    var ipSortKey: Int {
        let parts = self.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return 0 }
        return parts[0] * 16777216 + parts[1] * 65536 + parts[2] * 256 + parts[3]
    }
}

private actor ResumeState {
    private(set) var hasResumed = false
    
    func setResumed() {
        hasResumed = true
    }
}
