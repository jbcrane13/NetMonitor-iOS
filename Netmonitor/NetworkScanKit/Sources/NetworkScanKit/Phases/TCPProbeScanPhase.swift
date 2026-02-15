import Foundation
import Network

/// Discovers devices by attempting TCP connections to common service ports.
///
/// Skips IPs already found by earlier phases (ARP, Bonjour) to avoid redundant probes.
public struct TCPProbeScanPhase: ScanPhase, Sendable {
    public let id = "tcpProbe"
    public let displayName = "Probing ports…"
    public let weight: Double = 0.55

    /// Maximum number of hosts probed concurrently.
    let maxConcurrentHosts: Int

    /// Stage 1 ports: high-yield services for most LAN devices.
    static let primaryProbePorts: [UInt16] = [80, 443, 22, 445]

    /// Stage 2 ports: broaden coverage for IoT, printers, media devices, and Apple services.
    static let secondaryProbePorts: [UInt16] = [7000, 8080, 8443, 62078, 5353, 9100, 1883, 554, 548]

    private static let maxConcurrentPortProbes = 3
    private static let primaryProbeTimeout: Duration = .milliseconds(700)
    private static let secondaryProbeTimeout: Duration = .milliseconds(1200)

    public init(maxConcurrentHosts: Int = 12) {
        self.maxConcurrentHosts = maxConcurrentHosts
    }

    public func execute(
        context: ScanContext,
        accumulator: ScanAccumulator,
        onProgress: @Sendable (Double) async -> Void
    ) async {
        await onProgress(0.0)

        // Skip IPs already found by earlier phases
        let knownIPs = await accumulator.knownIPs()
        let hostsToProbe = knownIPs.isEmpty
            ? context.hosts
            : context.hosts.filter { !knownIPs.contains($0) }

        guard !hostsToProbe.isEmpty else {
            await onProgress(1.0)
            return
        }

        let total = hostsToProbe.count
        let concurrencyLimit = ThermalThrottleMonitor.shared.effectiveLimit(from: maxConcurrentHosts)
        var scannedCount = 0

        await withTaskGroup(of: DiscoveredDevice?.self) { group in
            var pending = 0
            var hostIterator = hostsToProbe.makeIterator()

            while pending < concurrencyLimit, let ip = hostIterator.next() {
                pending += 1
                group.addTask {
                    await Self.probeHost(ip)
                }
            }

            while let result = await group.next() {
                pending -= 1
                scannedCount += 1

                if let device = result {
                    await accumulator.upsert(device)
                }

                let progress = Double(scannedCount) / Double(max(total, 1))
                await onProgress(progress)

                if let ip = hostIterator.next() {
                    pending += 1
                    group.addTask {
                        await Self.probeHost(ip)
                    }
                }
            }
        }

        await onProgress(1.0)
    }

    // MARK: - Probe logic

    /// Result of probing a group of ports on a single host.
    private enum ProbeGroupResult: Sendable {
        case reachable(latency: Double)
        case allTimedOut
        case allFailed
    }

    /// Per-port probe outcome.
    private enum PortProbeOutcome: Sendable {
        case reachable(latency: Double)
        case refused(latency: Double)
        case timeout
        case failed
    }

    /// Probe a host with staged port groups and return first successful latency.
    private static func probeHost(_ ip: String) async -> DiscoveredDevice? {
        let primaryResult = await probePortGroup(
            ip: ip,
            ports: primaryProbePorts,
            timeout: primaryProbeTimeout,
            maxConcurrentPorts: maxConcurrentPortProbes
        )

        switch primaryResult {
        case .reachable(let latency):
            return DiscoveredDevice(ipAddress: ip, latency: latency, discoveredAt: Date())
        case .allTimedOut, .allFailed:
            break
        }

        let secondaryResult = await probePortGroup(
            ip: ip,
            ports: secondaryProbePorts,
            timeout: secondaryProbeTimeout,
            maxConcurrentPorts: maxConcurrentPortProbes
        )

        if case .reachable(let latency) = secondaryResult {
            return DiscoveredDevice(ipAddress: ip, latency: latency, discoveredAt: Date())
        }

        return nil
    }

    private static func probePortGroup(
        ip: String,
        ports: [UInt16],
        timeout: Duration,
        maxConcurrentPorts: Int
    ) async -> ProbeGroupResult {
        guard !ports.isEmpty else { return .allFailed }

        return await withTaskGroup(of: PortProbeOutcome.self, returning: ProbeGroupResult.self) { group in
            var pending = 0
            var iterator = ports.makeIterator()
            var sawTimeout = false

            while pending < maxConcurrentPorts, let port = iterator.next() {
                pending += 1
                group.addTask {
                    await probePort(ip: ip, port: port, timeout: timeout)
                }
            }

            while pending > 0 {
                guard let result = await group.next() else { break }
                pending -= 1

                switch result {
                case .reachable(let latency):
                    group.cancelAll()
                    return .reachable(latency: latency)
                case .refused(let latency):
                    group.cancelAll()
                    return .reachable(latency: latency)
                case .timeout:
                    sawTimeout = true
                case .failed:
                    break
                }

                if let port = iterator.next() {
                    pending += 1
                    group.addTask {
                        await probePort(ip: ip, port: port, timeout: timeout)
                    }
                }
            }

            return sawTimeout ? .allTimedOut : .allFailed
        }
    }

    private static func probePort(ip: String, port: UInt16, timeout: Duration) async -> PortProbeOutcome {
        await ConnectionBudget.shared.acquire()
        defer { Task { await ConnectionBudget.shared.release() } }

        let host = NWEndpoint.Host(ip)
        let endpoint = NWEndpoint.hostPort(host: host, port: NWEndpoint.Port(rawValue: port)!)
        let params = NWParameters.tcp
        params.requiredInterfaceType = .wifi

        let connection = NWConnection(to: endpoint, using: params)

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<PortProbeOutcome, Never>) in
            let resumed = ResumeState()

            let timeoutTask = Task {
                try? await Task.sleep(for: timeout)
                guard await resumed.tryResume() else { return }
                connection.cancel()
                continuation.resume(returning: .timeout)
            }

            let start = Date()

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()
                        continuation.resume(returning: .reachable(latency: elapsed))
                    }
                case .failed(let error):
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()

                        if case NWError.posix(let code) = error, code == .ECONNREFUSED {
                            continuation.resume(returning: .refused(latency: elapsed))
                        } else {
                            continuation.resume(returning: .failed)
                        }
                    }
                case .cancelled:
                    Task {
                        guard await resumed.tryResume() else { return }
                        timeoutTask.cancel()
                        connection.cancel()
                        continuation.resume(returning: .failed)
                    }
                default:
                    break
                }
            }

            connection.start(queue: scanQueue)
        }

        connection.cancel()
        return result
    }
}
