import Testing
import Foundation
@testable import Netmonitor
import NetworkScanKit

@Suite("ScanAccumulator Tests")
struct ScanAccumulatorTests {

    // MARK: - allDeviceIPs

    @Test("allDeviceIPs returns all device IPs after upsert")
    func allDeviceIPsReturnsAllIPs() async {
        let accumulator = ScanAccumulator()
        let now = Date()
        await accumulator.upsert(DiscoveredDevice(ipAddress: "192.168.1.1", latency: 10.0, discoveredAt: now))
        await accumulator.upsert(DiscoveredDevice(ipAddress: "192.168.1.2", latency: 20.0, discoveredAt: now))
        await accumulator.upsert(DiscoveredDevice(ipAddress: "192.168.1.3", latency: 30.0, discoveredAt: now))

        let ips = await accumulator.allDeviceIPs()
        #expect(ips.count == 3)
        #expect(ips.contains("192.168.1.1"))
        #expect(ips.contains("192.168.1.2"))
        #expect(ips.contains("192.168.1.3"))
    }

    @Test("allDeviceIPs returns empty array when no devices present")
    func allDeviceIPsEmptyWhenNoDevices() async {
        let accumulator = ScanAccumulator()
        let ips = await accumulator.allDeviceIPs()
        #expect(ips.isEmpty)
    }

    // MARK: - replaceLatency

    @Test("replaceLatency overwrites existing latency for known IP")
    func replaceLatencyOverwritesExistingLatency() async {
        let accumulator = ScanAccumulator()
        let now = Date()
        await accumulator.upsert(DiscoveredDevice(ipAddress: "192.168.1.10", latency: 50.0, discoveredAt: now))

        await accumulator.replaceLatency(ip: "192.168.1.10", latency: 5.0)

        let snapshot = await accumulator.snapshot()
        let device = snapshot.first { $0.ipAddress == "192.168.1.10" }
        #expect(device?.latency == 5.0)
    }

    @Test("replaceLatency with unknown IP is a no-op")
    func replaceLatencyUnknownIPIsNoOp() async {
        let accumulator = ScanAccumulator()
        let now = Date()
        await accumulator.upsert(DiscoveredDevice(ipAddress: "192.168.1.10", latency: 50.0, discoveredAt: now))

        await accumulator.replaceLatency(ip: "10.0.0.99", latency: 1.0)

        // Count unchanged, original device unaffected
        let count = await accumulator.count
        #expect(count == 1)
        let snapshot = await accumulator.snapshot()
        #expect(snapshot.first?.latency == 50.0)
    }

    // MARK: - updateLatency

    @Test("updateLatency sets latency when it is nil")
    func updateLatencySetsWhenNil() async {
        let accumulator = ScanAccumulator()
        let now = Date()
        // Use full init with nil latency
        await accumulator.upsert(DiscoveredDevice(
            ipAddress: "192.168.1.20",
            hostname: nil,
            vendor: nil,
            macAddress: nil,
            latency: nil,
            discoveredAt: now,
            source: .local
        ))

        await accumulator.updateLatency(ip: "192.168.1.20", latency: 15.0)

        let snapshot = await accumulator.snapshot()
        let device = snapshot.first { $0.ipAddress == "192.168.1.20" }
        #expect(device?.latency == 15.0)
    }

    @Test("updateLatency does not overwrite existing latency")
    func updateLatencyDoesNotOverwriteExistingLatency() async {
        let accumulator = ScanAccumulator()
        let now = Date()
        await accumulator.upsert(DiscoveredDevice(ipAddress: "192.168.1.20", latency: 25.0, discoveredAt: now))

        await accumulator.updateLatency(ip: "192.168.1.20", latency: 999.0)

        let snapshot = await accumulator.snapshot()
        let device = snapshot.first { $0.ipAddress == "192.168.1.20" }
        #expect(device?.latency == 25.0)
    }

    // MARK: - knownIPs

    @Test("knownIPs returns the correct set of known IP addresses")
    func knownIPsReturnsCorrectSet() async {
        let accumulator = ScanAccumulator()
        let now = Date()
        await accumulator.upsert(DiscoveredDevice(ipAddress: "10.0.0.1", latency: 1.0, discoveredAt: now))
        await accumulator.upsert(DiscoveredDevice(ipAddress: "10.0.0.2", latency: 2.0, discoveredAt: now))

        let known = await accumulator.knownIPs()
        #expect(known == Set(["10.0.0.1", "10.0.0.2"]))
    }

    @Test("knownIPs does not include duplicate IPs after upsert merge")
    func knownIPsNoDuplicatesAfterUpsert() async {
        let accumulator = ScanAccumulator()
        let now = Date()
        await accumulator.upsert(DiscoveredDevice(ipAddress: "10.0.0.1", latency: 1.0, discoveredAt: now))
        await accumulator.upsert(DiscoveredDevice(ipAddress: "10.0.0.1", latency: 2.0, discoveredAt: now))

        let known = await accumulator.knownIPs()
        #expect(known.count == 1)
        #expect(known.contains("10.0.0.1"))
    }

    // MARK: - sortedSnapshot

    @Test("sortedSnapshot returns devices sorted by IP address numerically")
    func sortedSnapshotSortsByIPNumerically() async {
        let accumulator = ScanAccumulator()
        let now = Date()
        // Insert in reverse order to verify sort
        await accumulator.upsert(DiscoveredDevice(ipAddress: "192.168.1.100", latency: 1.0, discoveredAt: now))
        await accumulator.upsert(DiscoveredDevice(ipAddress: "192.168.1.2", latency: 2.0, discoveredAt: now))
        await accumulator.upsert(DiscoveredDevice(ipAddress: "192.168.1.10", latency: 3.0, discoveredAt: now))

        let sorted = await accumulator.sortedSnapshot()
        #expect(sorted.count == 3)
        #expect(sorted[0].ipAddress == "192.168.1.2")
        #expect(sorted[1].ipAddress == "192.168.1.10")
        #expect(sorted[2].ipAddress == "192.168.1.100")
    }

    @Test("sortedSnapshot returns empty array when accumulator is empty")
    func sortedSnapshotEmptyWhenNoDevices() async {
        let accumulator = ScanAccumulator()
        let sorted = await accumulator.sortedSnapshot()
        #expect(sorted.isEmpty)
    }
}
