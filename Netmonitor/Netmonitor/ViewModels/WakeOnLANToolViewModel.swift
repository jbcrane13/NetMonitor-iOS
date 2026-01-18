import Foundation

/// ViewModel for the Wake on LAN tool view
@MainActor
@Observable
final class WakeOnLANToolViewModel {
    // MARK: - Input Properties

    var macAddress: String = ""
    var broadcastAddress: String = "255.255.255.255"

    // MARK: - State Properties

    var isSending: Bool = false
    var lastResult: WakeOnLANResult?
    var errorMessage: String?

    // MARK: - Dependencies

    private let wolService = WakeOnLANService()

    // MARK: - Computed Properties

    var canSend: Bool {
        !macAddress.trimmingCharacters(in: .whitespaces).isEmpty && !isSending && isValidMACAddress
    }

    var isValidMACAddress: Bool {
        let cleaned = macAddress
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
        return cleaned.count == 12 && cleaned.allSatisfy { $0.isHexDigit }
    }

    var formattedMACAddress: String {
        let cleaned = macAddress
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()

        guard cleaned.count == 12 else { return macAddress }

        var result = ""
        for (index, char) in cleaned.enumerated() {
            if index > 0 && index % 2 == 0 {
                result += ":"
            }
            result.append(char)
        }
        return result
    }

    // MARK: - Actions

    func sendWakePacket() async {
        guard canSend else { return }

        isSending = true
        errorMessage = nil

        let success = await wolService.wake(
            macAddress: macAddress.trimmingCharacters(in: .whitespaces),
            broadcastAddress: broadcastAddress
        )

        lastResult = wolService.lastResult

        if !success {
            errorMessage = wolService.lastError ?? "Failed to send wake packet"
        }

        isSending = false
    }

    func clearResults() {
        lastResult = nil
        errorMessage = nil
    }
}
