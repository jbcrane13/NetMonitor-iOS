import Foundation

/// ViewModel for the Port Scanner tool view
@MainActor
@Observable
final class PortScannerToolViewModel {
    // MARK: - Input Properties

    var host: String = ""
    var portRange: PortRange = .common

    // MARK: - State Properties

    var isRunning: Bool = false
    var results: [PortScanResult] = []
    var errorMessage: String?
    var scannedCount: Int = 0

    // MARK: - Configuration

    enum PortRange: String, CaseIterable {
        case common = "Common Ports"
        case wellKnown = "Well-Known (1-1024)"
        case extended = "Extended (1-10000)"
        case custom = "Custom"

        var ports: [Int] {
            switch self {
            case .common:
                return [20, 21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 993, 995, 3306, 3389, 5432, 5900, 8080, 8443]
            case .wellKnown:
                return Array(1...1024)
            case .extended:
                return Array(1...10000)
            case .custom:
                return []
            }
        }
    }

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
        portRange.ports.count
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
                ports: portRange.ports
            )

            for await result in stream {
                results.append(result)
                scannedCount += 1
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
