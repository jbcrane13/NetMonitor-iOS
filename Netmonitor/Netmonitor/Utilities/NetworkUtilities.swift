import Foundation

/// Shared network interface utilities for detecting local IP addresses and subnets.
enum NetworkUtilities {
    /// Detects the local IP address for a given network interface.
    /// - Parameter interface: The interface name (default: "en0" for WiFi)
    /// - Returns: The IP address string, or nil if not found
    static func detectLocalIPAddress(interface: String = "en0") -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let iface = ptr.pointee
            let addrFamily = iface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: iface.ifa_name)
                if name == interface {
                    var addr = iface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        &addr,
                        socklen_t(iface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    return String(cString: hostname)
                }
            }
        }
        return nil
    }

    /// Detects the subnet prefix for a given network interface.
    /// - Parameter interface: The interface name (default: "en0" for WiFi)
    /// - Returns: The subnet prefix (e.g., "192.168.1"), or nil if not found
    static func detectSubnet(interface: String = "en0") -> String? {
        guard let ipAddress = detectLocalIPAddress(interface: interface) else {
            return nil
        }
        let components = ipAddress.split(separator: ".")
        if components.count == 4 {
            return "\(components[0]).\(components[1]).\(components[2])"
        }
        return nil
    }

    /// Detects the default gateway IP address (assumes .1 on the local subnet).
    /// - Parameter interface: The interface name (default: "en0" for WiFi)
    /// - Returns: The gateway IP address, or nil if not found
    static func detectDefaultGateway(interface: String = "en0") -> String? {
        guard let subnet = detectSubnet(interface: interface) else {
            return nil
        }
        return "\(subnet).1"
    }
}
