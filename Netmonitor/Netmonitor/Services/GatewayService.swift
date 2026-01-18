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

        guard let gatewayIP = NetworkUtilities.detectDefaultGateway() else {
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

    private nonisolated func measureLatency(to host: String) async -> Double? {
        let start = Date()

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: 80) ?? .http
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
                        let latency = Date().timeIntervalSince(start) * 1000
                        connection.cancel()
                        continuation.resume(returning: latency)
                    case .failed, .cancelled:
                        await resumeState.setResumed()
                        continuation.resume(returning: nil)
                    default:
                        break
                    }
                }
            }

            connection.start(queue: .global())

            Task {
                try? await Task.sleep(for: .seconds(5))
                guard await !resumeState.hasResumed else { return }
                await resumeState.setResumed()
                connection.cancel()
                continuation.resume(returning: nil)
            }
        }
    }
}
