import Foundation
import Network
import NetworkScanKit

actor PingService {
    /// Reference-type timestamp for Sendable closure capture.
    /// Thread-safe because reads/writes are serialized on pingQueue.
    private final class DateRef: @unchecked Sendable {
        var value = Date()
    }

    private var isRunning = false
    private var activeRunID: UUID?

    /// Dedicated queue isolates ping measurements from device scan traffic on .global().
    private nonisolated let pingQueue = DispatchQueue(label: "com.netmonitor.ping", qos: .userInteractive)
    
    func ping(
        host: String,
        count: Int = 4,
        timeout: TimeInterval = 5
    ) -> AsyncStream<PingResult> {
        AsyncStream { continuation in
            Task {
                let runID = self.beginRun()

                let resolvedIP = await resolveHost(host)

                for seq in 1...count {
                    guard self.shouldContinue(runID: runID) else { break }

                    let (success, connectTime) = await self.connectTest(
                        host: resolvedIP ?? host,
                        timeout: timeout
                    )
                    let elapsed = connectTime * 1000

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

                self.endRun(runID: runID)
                continuation.finish()
            }
        }
    }
    
    func stop() async {
        isRunning = false
        activeRunID = nil
    }
    
    private func beginRun() -> UUID {
        let runID = UUID()
        activeRunID = runID
        isRunning = true
        return runID
    }

    private func shouldContinue(runID: UUID) -> Bool {
        isRunning && activeRunID == runID
    }

    private func endRun(runID: UUID) {
        guard activeRunID == runID else { return }
        activeRunID = nil
        isRunning = false
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
    /// Measures only the TCP handshake: timestamps captured synchronously on pingQueue,
    /// before any Task spawn or actor hop.
    private func connectTest(host: String, timeout: TimeInterval) async -> (success: Bool, elapsed: TimeInterval) {
        let ports: [NWEndpoint.Port] = [.https, .http, NWEndpoint.Port(rawValue: 22)!]
        let hostEndpoint = NWEndpoint.Host(host)

        let queue = pingQueue
        return await withTaskGroup(of: (Bool, TimeInterval).self, returning: (Bool, TimeInterval).self) { group in
            for port in ports {
                group.addTask {
                    await ConnectionBudget.shared.acquire()
                    let connection = NWConnection(to: .hostPort(host: hostEndpoint, port: port), using: .tcp)
                    defer {
                        connection.cancel()
                        Task { await ConnectionBudget.shared.release() }
                    }

                    return await withCheckedContinuation { (continuation: CheckedContinuation<(Bool, TimeInterval), Never>) in
                        let resumed = ResumeState()
                        let startTime = DateRef()

                        let timeoutTask = Task {
                            try? await Task.sleep(for: .seconds(timeout))
                            guard await resumed.tryResume() else { return }
                            connection.cancel()
                            continuation.resume(returning: (false, timeout))
                        }

                        connection.stateUpdateHandler = { state in
                            // Capture elapsed SYNCHRONOUSLY on pingQueue — true handshake time.
                            let elapsed = Date().timeIntervalSince(startTime.value)
                            switch state {
                            case .ready:
                                Task {
                                    guard await resumed.tryResume() else { return }
                                    timeoutTask.cancel()
                                    connection.cancel()
                                    continuation.resume(returning: (true, elapsed))
                                }
                            case .failed(let error):
                                Task {
                                    guard await resumed.tryResume() else { return }
                                    timeoutTask.cancel()
                                    connection.cancel()

                                    // A refused TCP handshake still proves the host is reachable.
                                    if case NWError.posix(let code) = error, code == .ECONNREFUSED {
                                        continuation.resume(returning: (true, elapsed))
                                    } else {
                                        continuation.resume(returning: (false, elapsed))
                                    }
                                }
                            case .cancelled:
                                Task {
                                    guard await resumed.tryResume() else { return }
                                    timeoutTask.cancel()
                                    connection.cancel()
                                    continuation.resume(returning: (false, elapsed))
                                }
                            default:
                                break
                            }
                        }

                        startTime.value = Date()
                        connection.start(queue: queue)
                    }
                }
            }

            // Return true as soon as any port succeeds, with its elapsed time
            var bestElapsed: TimeInterval = 0
            for await (success, elapsed) in group {
                if success {
                    group.cancelAll()
                    return (true, elapsed)
                }
                bestElapsed = max(bestElapsed, elapsed)
            }
            return (false, bestElapsed)
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
