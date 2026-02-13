import Foundation
import Network

actor PingService {
    private var isRunning = false
    
    func ping(
        host: String,
        count: Int = 4,
        timeout: TimeInterval = 5
    ) -> AsyncStream<PingResult> {
        AsyncStream { continuation in
            Task {
                self.setRunning(true)
                defer { Task { self.setRunning(false) } }

                let resolvedIP = await resolveHost(host)

                for seq in 1...count {
                    guard self.isRunning else { break }

                    let start = Date()
                    let success = await connectTest(
                        host: resolvedIP ?? host,
                        timeout: timeout
                    )
                    let elapsed = Date().timeIntervalSince(start) * 1000

                    let result = PingResult(
                        sequence: seq,
                        host: host,
                        ipAddress: resolvedIP,
                        ttl: success ? 64 : 0,
                        time: elapsed,
                        size: 64,
                        isTimeout: !success
                    )
                    continuation.yield(result)

                    if seq < count {
                        try? await Task.sleep(for: .seconds(1))
                    }
                }

                continuation.finish()
            }
        }
    }
    
    func stop() async {
        isRunning = false
    }
    
    private func setRunning(_ value: Bool) {
        isRunning = value
    }
    
    private func resolveHost(_ host: String) async -> String? {
        guard !isIPAddress(host) else { return host }
        
        return await withCheckedContinuation { continuation in
            let host = CFHostCreateWithName(nil, host as CFString).takeRetainedValue()
            var resolved = DarwinBoolean(false)
            
            CFHostStartInfoResolution(host, .addresses, nil)
            
            guard let addresses = CFHostGetAddressing(host, &resolved)?.takeUnretainedValue() as? [Data],
                  let addressData = addresses.first else {
                continuation.resume(returning: nil)
                return
            }
            
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            addressData.withUnsafeBytes { ptr in
                let sockaddr = ptr.bindMemory(to: sockaddr.self).baseAddress!
                getnameinfo(sockaddr, socklen_t(addressData.count),
                           &hostname, socklen_t(hostname.count),
                           nil, 0, NI_NUMERICHOST)
            }
            
            let length = strnlen(hostname, hostname.count)
            let bytes = hostname.prefix(length).map { UInt8(bitPattern: $0) }
            let ip = String(decoding: bytes, as: UTF8.self)
            continuation.resume(returning: ip.isEmpty ? nil : ip)
        }
    }
    
    /// Try connecting to multiple common ports concurrently — succeed if ANY responds.
    /// This is far more reliable than single-port (80) since many hosts only listen on
    /// 443 (HTTPS) or 22 (SSH) but not 80.
    private func connectTest(host: String, timeout: TimeInterval) async -> Bool {
        let ports: [NWEndpoint.Port] = [.https, .http, NWEndpoint.Port(rawValue: 22)!]
        let hostEndpoint = NWEndpoint.Host(host)
        
        let connections = ports.map { port -> NWConnection in
            NWConnection(to: .hostPort(host: hostEndpoint, port: port), using: .tcp)
        }
        defer { connections.forEach { $0.cancel() } }
        
        return await withTaskGroup(of: Bool.self, returning: Bool.self) { group in
            for connection in connections {
                nonisolated(unsafe) let conn = connection
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                        let resumed = ResumeState()
                        
                        let timeoutTask = Task {
                            try? await Task.sleep(for: .seconds(timeout))
                            guard await resumed.tryResume() else { return }
                            conn.cancel()
                            continuation.resume(returning: false)
                        }
                        
                        conn.stateUpdateHandler = { state in
                            switch state {
                            case .ready:
                                Task {
                                    guard await resumed.tryResume() else { return }
                                    timeoutTask.cancel()
                                    conn.cancel()
                                    continuation.resume(returning: true)
                                }
                            case .failed, .cancelled, .waiting:
                                Task {
                                    guard await resumed.tryResume() else { return }
                                    timeoutTask.cancel()
                                    conn.cancel()
                                    continuation.resume(returning: false)
                                }
                            default:
                                break
                            }
                        }
                        
                        conn.start(queue: .global())
                    }
                }
            }
            
            // Return true as soon as any port succeeds
            for await result in group {
                if result {
                    group.cancelAll()
                    return true
                }
            }
            return false
        }
    }
    
    private func isIPAddress(_ string: String) -> Bool {
        var addr = in_addr()
        var addr6 = in6_addr()
        return inet_pton(AF_INET, string, &addr) == 1 ||
               inet_pton(AF_INET6, string, &addr6) == 1
    }
    
    func calculateStatistics(_ results: [PingResult], requestedCount: Int? = nil) async -> PingStatistics? {
        guard !results.isEmpty else { return nil }

        let transmitted = requestedCount ?? results.count
        let successfulResults = results.filter { !$0.isTimeout }
        let received = successfulResults.count

        let packetLoss = transmitted > 0
            ? Double(transmitted - received) / Double(transmitted) * 100.0
            : 0.0

        let times = successfulResults.map(\.time)
        let minTime = times.min() ?? 0
        let maxTime = times.max() ?? 0
        let avgTime = times.isEmpty ? 0 : times.reduce(0, +) / Double(times.count)

        let variance = times.isEmpty ? 0 : times.map { pow($0 - avgTime, 2) }.reduce(0, +) / Double(times.count)
        let stdDev = sqrt(variance)

        return PingStatistics(
            host: results.first?.host ?? "",
            transmitted: transmitted,
            received: received,
            packetLoss: packetLoss,
            minTime: minTime,
            maxTime: maxTime,
            avgTime: avgTime,
            stdDev: stdDev
        )
    }
}

