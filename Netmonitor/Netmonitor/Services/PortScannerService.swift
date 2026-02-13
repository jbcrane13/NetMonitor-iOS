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
        let resumeState = ResumeState()
        
        let state = await withCheckedContinuation { (continuation: CheckedContinuation<PortState, Never>) in
            connection.stateUpdateHandler = { state in
                Task {
                    guard await !resumeState.hasResumed else { return }
                    
                    switch state {
                    case .ready:
                        await resumeState.setResumed()
                        connection.cancel()
                        continuation.resume(returning: .open)
                    case .failed(let error):
                        await resumeState.setResumed()
                        connection.cancel()
                        if case NWError.posix(let code) = error, code == .ECONNREFUSED {
                            continuation.resume(returning: .closed)
                        } else {
                            continuation.resume(returning: .filtered)
                        }
                    case .cancelled:
                        guard await !resumeState.hasResumed else { return }
                        await resumeState.setResumed()
                        continuation.resume(returning: .filtered)
                    default:
                        break
                    }
                }
            }
            
            connection.start(queue: .global())
            
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                guard await !resumeState.hasResumed else { return }
                await resumeState.setResumed()
                connection.cancel()
                continuation.resume(returning: .filtered)
            }
        }
        
        let elapsed = Date().timeIntervalSince(start) * 1000
        
        return PortScanResult(
            port: port,
            state: state,
            serviceName: PortScanResult.commonServiceName(for: port),
            banner: nil,
            responseTime: state == .open ? elapsed : nil
        )
    }
}

