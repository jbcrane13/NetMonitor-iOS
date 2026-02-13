import Foundation
import Network

actor PortScannerService {
    private var isRunning = false
    private let maxConcurrent = 50
    
    func scan(
        host: String,
        ports: [Int],
        timeout: TimeInterval = 2
    ) -> AsyncStream<PortScanResult> {
        AsyncStream { continuation in
            Task {
                self.setRunning(true)
                defer { Task { self.setRunning(false) } }
                
                await withTaskGroup(of: PortScanResult.self) { group in
                    var pending = 0
                    var portIterator = ports.makeIterator()
                    
                    while self.isRunning {
                        while pending < maxConcurrent, let port = portIterator.next() {
                            pending += 1
                            group.addTask {
                                await self.scanPort(host: host, port: port, timeout: timeout)
                            }
                        }
                        
                        guard let result = await group.next() else { break }
                        pending -= 1
                        
                        continuation.yield(result)
                    }
                }
                
                continuation.finish()
            }
        }
    }
    
    func stop() {
        Task { setRunning(false) }
    }
    
    private func setRunning(_ value: Bool) {
        isRunning = value
    }
    
    private func scanPort(host: String, port: Int, timeout: TimeInterval) async -> PortScanResult {
        let start = Date()
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port))!
        )
        
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        
        let connection = NWConnection(to: endpoint, using: parameters)
        defer {
            connection.stateUpdateHandler = nil
            connection.cancel()
        }
        
        let portState = await withCheckedContinuation { (continuation: CheckedContinuation<PortState, Never>) in
            let resumed = ResumeState()
            
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(timeout))
                guard await resumed.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: .filtered)
            }
            
            connection.stateUpdateHandler = { [weak connection] state in
                switch state {
                case .ready:
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection?.cancel()
                        continuation.resume(returning: .open)
                    }
                case .failed(let error):
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection?.cancel()
                        if case NWError.posix(let code) = error, code == .ECONNREFUSED {
                            continuation.resume(returning: .closed)
                        } else {
                            continuation.resume(returning: .filtered)
                        }
                    }
                case .cancelled:
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        continuation.resume(returning: .filtered)
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
        
        let elapsed = Date().timeIntervalSince(start) * 1000
        
        return PortScanResult(
            port: port,
            state: portState,
            serviceName: PortScanResult.commonServiceName(for: port),
            banner: nil,
            responseTime: portState == .open ? elapsed : nil
        )
    }
}

