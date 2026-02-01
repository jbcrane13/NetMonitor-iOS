import Foundation

/// ViewModel for the Port Scanner tool view
@MainActor
@Observable
final class PortScannerToolViewModel {
    // MARK: - Input Properties

    var host: String = ""
    var portPreset: PortScanPreset = .common

    // MARK: - State Properties

    var isRunning: Bool = false
    var results: [PortScanResult] = []
    var errorMessage: String?
    var scannedCount: Int = 0

    // MARK: - Dependencies

    private let portScannerService = PortScannerService()
    private var scanTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var canStartScan: Bool {
        !host.trimmingCharacters(in: .whitespaces).isEmpty && !isRunning
    }

    var openPorts: [PortScanResult] {
        results.filter { $0.state == .open }
    }

    var totalPorts: Int {
        portPreset.ports.count
    }

    var progress: Double {
        guard totalPorts > 0 else { return 0 }
        return Double(scannedCount) / Double(totalPorts)
    }

    // MARK: - Actions

    func startScan() {
        guard canStartScan else { return }

        clearResults()
        isRunning = true
        scannedCount = 0

        scanTask = Task {
            let stream = await portScannerService.scan(
                host: host.trimmingCharacters(in: .whitespaces),
                ports: portPreset.ports
            )

            for await result in stream {
                scannedCount += 1
                if result.state == .open {
                    results.append(result)
                }
            }

            // Sort by port number
            results.sort { $0.port < $1.port }
            isRunning = false
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        Task {
            await portScannerService.stop()
        }
        isRunning = false
    }

    func clearResults() {
        results.removeAll()
        scannedCount = 0
        errorMessage = nil
    }
}
