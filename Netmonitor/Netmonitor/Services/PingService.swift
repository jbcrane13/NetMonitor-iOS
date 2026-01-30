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
                await self.setRunning(true)
                defer { Task { await self.setRunning(false) } }

                let resolvedIP = await resolveHost(host)

                for seq in 1...count {
                    guard await self.isRunning else { break }

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
    
    func stop() {
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
            
            let ip = String(cString: hostname)
            continuation.resume(returning: ip.isEmpty ? nil : ip)
        }
    }
    
    private func connectTest(host: String, timeout: TimeInterval) async -> Bool {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: .http
        )
        
        let connection = NWConnection(to: endpoint, using: .tcp)
        let resumeState = ResumeState()
        
        return await withCheckedContinuation { continuation in
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
                try? await Task.sleep(for: .seconds(timeout))
                guard await !resumeState.hasResumed else { return }
                await resumeState.setResumed()
                connection.cancel()
                continuation.resume(returning: false)
            }
        }
    }
    
    private func isIPAddress(_ string: String) -> Bool {
        var addr = in_addr()
        var addr6 = in6_addr()
        return inet_pton(AF_INET, string, &addr) == 1 ||
               inet_pton(AF_INET6, string, &addr6) == 1
    }
    
    func calculateStatistics(_ results: [PingResult], requestedCount: Int? = nil) -> PingStatistics? {
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

