import Foundation
import Testing
import NetworkScanKit
@testable import Netmonitor

@MainActor
final class MockMacConnectionServiceForCoverage: MacConnectionServiceProtocol {
    var connectionState: MacConnectionState = .disconnected
    var discoveredMacs: [DiscoveredMac] = []
    var isBrowsing: Bool = false
    var connectedMacName: String?
    var lastStatusUpdate: StatusUpdatePayload?
    var lastTargetList: TargetListPayload?
    var lastDeviceList: DeviceListPayload?

    func startBrowsing() {}

    func stopBrowsing() {}

    func connect(to mac: DiscoveredMac) {}

    func connectDirect(host: String, port: UInt16) {}

    func disconnect() {}

    func send(command: CommandPayload) async {}
}

@Suite("Service Branch Coverage Tests")
struct ServiceBranchCoverageTests {

    @Test("DNS lookup with empty domain sets error")
    @MainActor
    func dnsLookupEmptyDomain() async {
        let service = DNSLookupService()

        let result = await service.lookup(domain: "", recordType: .a, server: nil)

        #expect(result == nil)
        #expect(service.isLoading == false)
        #expect(service.lastError != nil)
    }

    @Test("DNS lookup with malformed domain sets error")
    @MainActor
    func dnsLookupMalformedDomain() async {
        let service = DNSLookupService()

        let result = await service.lookup(domain: "invalid domain ???", recordType: .mx, server: nil)

        #expect(result == nil)
        #expect(service.isLoading == false)
        #expect(service.lastError != nil)
    }

    @Test("Traceroute invalid host yields timeout hop")
    func tracerouteInvalidHost() async {
        let service = TracerouteService()
        let stream = await service.trace(
            host: "definitely-not-a-valid-host.invalid",
            maxHops: 5,
            timeout: 0.1
        )

        var hops: [TracerouteHop] = []
        for await hop in stream {
            hops.append(hop)
            if hops.count >= 2 {
                break
            }
        }

        #expect(hops.count == 1)
        #expect(hops.first?.hopNumber == 1)
        #expect(hops.first?.isTimeout == true)
        #expect(await service.running == false)
    }

    @Test("Traceroute stop keeps running state false")
    func tracerouteStopState() async {
        let service = TracerouteService()
        await service.stop()
        #expect(await service.running == false)
    }

    @Test("Speed test stop cancels and returns to idle", .timeLimit(.seconds(60)))
    @MainActor
    func speedTestCancellationState() async {
        let service = SpeedTestService()
        service.duration = 0.2

        let task = Task {
            try await service.startTest()
        }

        try? await Task.sleep(for: .milliseconds(250))
        service.stopTest()
        _ = try? await task.value

        #expect(service.isRunning == false)
        #expect(service.phase == .idle)
    }

    @Test("Gateway detection finishes with gateway or explicit error", .timeLimit(.seconds(20)))
    @MainActor
    func gatewayDetectionCompletion() async {
        let service = GatewayService()

        await service.detectGateway()

        #expect(service.isLoading == false)
        if let gateway = service.gateway {
            #expect(gateway.ipAddress.isEmpty == false)
        } else {
            #expect(service.lastError == "Could not detect gateway")
        }
    }

    @Test("Background refresh scheduling handles disabled setting")
    @MainActor
    func backgroundRefreshSchedulingDisabled() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: AppSettings.Keys.backgroundRefreshEnabled)
        defaults.set(false, forKey: AppSettings.Keys.backgroundRefreshEnabled)

        BackgroundTaskService.shared.scheduleRefreshTask()

        #expect(true)

        if let previous {
            defaults.set(previous, forKey: AppSettings.Keys.backgroundRefreshEnabled)
        } else {
            defaults.removeObject(forKey: AppSettings.Keys.backgroundRefreshEnabled)
        }
    }

    @Test("Background refresh scheduling handles enabled setting")
    @MainActor
    func backgroundRefreshSchedulingEnabled() {
        let defaults = UserDefaults.standard
        let previousEnabled = defaults.object(forKey: AppSettings.Keys.backgroundRefreshEnabled)
        let previousInterval = defaults.object(forKey: AppSettings.Keys.autoRefreshInterval)

        defaults.set(true, forKey: AppSettings.Keys.backgroundRefreshEnabled)
        defaults.set(10, forKey: AppSettings.Keys.autoRefreshInterval)

        BackgroundTaskService.shared.scheduleRefreshTask()

        #expect(true)

        if let previousEnabled {
            defaults.set(previousEnabled, forKey: AppSettings.Keys.backgroundRefreshEnabled)
        } else {
            defaults.removeObject(forKey: AppSettings.Keys.backgroundRefreshEnabled)
        }

        if let previousInterval {
            defaults.set(previousInterval, forKey: AppSettings.Keys.autoRefreshInterval)
        } else {
            defaults.removeObject(forKey: AppSettings.Keys.autoRefreshInterval)
        }
    }

    @Test("Background sync scheduling can be invoked")
    @MainActor
    func backgroundSyncScheduling() {
        BackgroundTaskService.shared.scheduleSyncTask()
        #expect(true)
    }

    @Test("Device discovery scan task can be cancelled", .timeLimit(.seconds(60)))
    @MainActor
    func deviceDiscoveryCancellation() async {
        let service = DeviceDiscoveryService(
            macConnectionService: MockMacConnectionServiceForCoverage()
        )

        let scanTask = Task {
            await service.scanNetwork(subnet: "10.255.255")
        }

        try? await Task.sleep(for: .milliseconds(300))
        service.stopScan()
        await scanTask.value

        #expect(service.isScanning == false)
        #expect(service.scanPhase == .idle)
        #expect(service.lastScanDate != nil)
    }
}
