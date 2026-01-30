import Foundation

/// Unified error type for all network service operations
enum NetworkError: LocalizedError {
    case timeout
    case connectionFailed
    case noNetwork
    case invalidHost
    case permissionDenied
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .timeout: "Connection timed out"
        case .connectionFailed: "Could not connect to host"
        case .noNetwork: "No network connection available"
        case .invalidHost: "Invalid hostname or IP address"
        case .permissionDenied: "Permission denied"
        case .unknown(let error): error.localizedDescription
        }
    }

    var userFacingMessage: String {
        switch self {
        case .timeout: "The connection timed out. Please check the host and try again."
        case .connectionFailed: "Unable to establish a connection. Please verify the host is reachable."
        case .noNetwork: "No network connection. Please check your internet connection."
        case .invalidHost: "The hostname or IP address is invalid. Please check and try again."
        case .permissionDenied: "Network permission was denied. Please check your settings."
        case .unknown: "An unexpected error occurred. Please try again."
        }
    }
}
