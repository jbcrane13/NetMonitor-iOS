import Foundation
import Network

private actor WOLResumeState {
    private var hasResumed = false
    
    func tryResume() -> Bool {
        if hasResumed { return false }
        hasResumed = true
        return true
    }
    
    func isResumed() -> Bool {
        return hasResumed
    }
}

@MainActor
@Observable
final class WakeOnLANService {
    private(set) var lastResult: WakeOnLANResult?
    private(set) var isSending: Bool = false
    private(set) var lastError: String?
    
    func wake(macAddress: String, broadcastAddress: String = "255.255.255.255", port: UInt16 = 9) async -> Bool {
        isSending = true
        lastError = nil
        
        defer { isSending = false }
        
        guard let packet = createMagicPacket(macAddress: macAddress) else {
            lastError = "Invalid MAC address format"
            lastResult = WakeOnLANResult(macAddress: macAddress, success: false, error: lastError)
            return false
        }
        
        let success = await sendPacket(packet, to: broadcastAddress, port: port)
        
        lastResult = WakeOnLANResult(
            macAddress: macAddress,
            success: success,
            error: success ? nil : "Failed to send packet"
        )
        
        return success
    }
    
    private func createMagicPacket(macAddress: String) -> Data? {
        let cleanedMAC = macAddress
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        
        guard cleanedMAC.count == 12,
              let macBytes = hexStringToBytes(cleanedMAC) else {
            return nil
        }
        
        var packet = Data(repeating: 0xFF, count: 6)
        
        for _ in 0..<16 {
            packet.append(contentsOf: macBytes)
        }
        
        return packet
    }
    
    private func hexStringToBytes(_ hex: String) -> [UInt8]? {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }
        
        return bytes
    }
    
    private func sendPacket(_ packet: Data, to address: String, port: UInt16) async -> Bool {
        let resumeState = WOLResumeState()
        
        return await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(address),
                port: NWEndpoint.Port(rawValue: port)!
            )
            
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            
            let connection = NWConnection(to: endpoint, using: parameters)
            
            connection.stateUpdateHandler = { [resumeState] state in
                switch state {
                case .ready:
                    connection.send(content: packet, completion: .contentProcessed { [resumeState] error in
                        Task {
                            if await resumeState.tryResume() {
                                connection.cancel()
                                continuation.resume(returning: error == nil)
                            }
                        }
                    })
                case .failed, .cancelled:
                    Task {
                        if await resumeState.tryResume() {
                            continuation.resume(returning: false)
                        }
                    }
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout after 5 seconds
            Task {
                try? await Task.sleep(for: .seconds(5))
                if await resumeState.tryResume() {
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

struct WakeOnLANResult {
    let macAddress: String
    let success: Bool
    let error: String?
    let timestamp: Date
    
    init(macAddress: String, success: Bool, error: String? = nil) {
        self.macAddress = macAddress
        self.success = success
        self.error = error
        self.timestamp = Date()
    }
}
