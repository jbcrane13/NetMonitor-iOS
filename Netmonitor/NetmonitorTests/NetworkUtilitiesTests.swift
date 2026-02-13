import Foundation
import Testing
@testable import Netmonitor

@Suite("NetworkUtilities IPv4Network Tests")
struct NetworkUtilitiesIPv4NetworkTests {

    @Test("contains(ipAddress:) matches addresses inside and outside the subnet")
    func containsAddresses() {
        let network = NetworkUtilities.IPv4Network(
            networkAddress: ipv4(192, 168, 1, 0),
            broadcastAddress: ipv4(192, 168, 1, 255),
            interfaceAddress: ipv4(192, 168, 1, 42),
            netmask: ipv4(255, 255, 255, 0)
        )

        #expect(network.contains(ipAddress: "192.168.1.1"))
        #expect(network.contains(ipAddress: "192.168.1.254"))
        #expect(!network.contains(ipAddress: "192.168.2.10"))
        #expect(!network.contains(ipAddress: "not-an-ip"))
    }

    @Test("hostAddresses excludes interface and returns usable /24 hosts")
    func hostAddressesFor24() {
        let network = NetworkUtilities.IPv4Network(
            networkAddress: ipv4(192, 168, 1, 0),
            broadcastAddress: ipv4(192, 168, 1, 255),
            interfaceAddress: ipv4(192, 168, 1, 42),
            netmask: ipv4(255, 255, 255, 0)
        )

        let hosts = network.hostAddresses(limit: 1024)

        #expect(hosts.count == 253)
        #expect(!hosts.contains("192.168.1.42"))
        #expect(hosts.first == "192.168.1.1")
        #expect(hosts.last == "192.168.1.254")
    }

    @Test("hostAddresses caps large subnets with a centered window")
    func hostAddressesLargeSubnetWithLimit() {
        let network = NetworkUtilities.IPv4Network(
            networkAddress: ipv4(10, 0, 0, 0),
            broadcastAddress: ipv4(10, 0, 15, 255),
            interfaceAddress: ipv4(10, 0, 8, 10),
            netmask: ipv4(255, 255, 240, 0)
        )

        let hosts = network.hostAddresses(limit: 128)

        #expect(hosts.count == 128)
        #expect(!hosts.contains("10.0.8.10"))
        #expect(hosts.contains("10.0.8.9"))
        #expect(hosts.contains("10.0.8.11"))
    }

    @Test("hostAddresses handles tiny subnets")
    func hostAddressesTinySubnet() {
        let network = NetworkUtilities.IPv4Network(
            networkAddress: ipv4(192, 168, 10, 0),
            broadcastAddress: ipv4(192, 168, 10, 3),
            interfaceAddress: ipv4(192, 168, 10, 1),
            netmask: ipv4(255, 255, 255, 252)
        )

        let hosts = network.hostAddresses(limit: 100)

        #expect(hosts.count == 1)
        #expect(hosts[0] == "192.168.10.2")
    }

    private func ipv4(_ a: UInt32, _ b: UInt32, _ c: UInt32, _ d: UInt32) -> UInt32 {
        (a << 24) | (b << 16) | (c << 8) | d
    }
}
