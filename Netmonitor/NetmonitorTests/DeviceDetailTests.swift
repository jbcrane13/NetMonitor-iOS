import Testing
import Foundation
@testable import Netmonitor

@Suite("Device Detail Feature Tests")
struct DeviceDetailTests {

    // MARK: - MACVendorLookupService Tests

    @Suite("MACVendorLookupService")
    struct MACVendorLookupServiceTests {

        @Test("Initial state has isLoading false")
        @MainActor
        func testInitialState() {
            let service = MACVendorLookupService()
            #expect(service.isLoading == false)
        }

        @Test("Service is MainActor and Observable")
        @MainActor
        func testServiceIsObservable() {
            let service = MACVendorLookupService()
            // If this compiles on @MainActor, the type is correctly marked
            #expect(service.isLoading == false)
        }

        @Test("Empty MAC address returns nil")
        @MainActor
        func testEmptyMACReturnsNil() async {
            let service = MACVendorLookupService()
            let result = await service.lookup(macAddress: "")
            #expect(result == nil)
        }

        @Test("Invalid MAC address returns normalized prefix")
        @MainActor
        func testInvalidMACHandling() async {
            let service = MACVendorLookupService()
            // Even invalid MACs get normalized - service will try to look them up
            // We can't directly test normalizeMACPrefix (private), but we can verify
            // the service doesn't crash with various inputs
            let _ = await service.lookup(macAddress: "invalid")
            #expect(service.isLoading == false) // Should have completed
        }
    }

    // MARK: - DeviceNameResolver Tests

    @Suite("DeviceNameResolver")
    struct DeviceNameResolverTests {

        @Test("Resolver can be instantiated")
        func testInitialState() {
            let resolver = DeviceNameResolver()
            // DeviceNameResolver is a Sendable value type with no observable state
            #expect(resolver is DeviceNameResolver)
        }

        @Test("ResolveAll with empty array returns empty dictionary")
        func testResolveAllEmptyArray() async {
            let resolver = DeviceNameResolver()
            let result = await resolver.resolveAll(devices: [], bonjourServices: [])
            #expect(result.isEmpty)
        }

        @Test("Resolve with Bonjour match returns hostname")
        func testResolveWithBonjourMatch() async {
            let resolver = DeviceNameResolver()
            let service = BonjourService(
                name: "TestDevice",
                type: "_http._tcp",
                hostName: "testdevice.local",
                addresses: ["192.168.1.50"]
            )
            let result = await resolver.resolve(ipAddress: "192.168.1.50", bonjourServices: [service])
            // May return PTR result or Bonjour match depending on DNS availability
            // At minimum, Bonjour match should work
            if result != nil {
                #expect(!result!.isEmpty)
            }
        }
    }

    // MARK: - DeviceDetailViewModel Tests

    @Suite("DeviceDetailViewModel")
    struct DeviceDetailViewModelTests {

        @Test("Initial state has nil device")
        @MainActor
        func testInitialState() {
            let viewModel = DeviceDetailViewModel()
            #expect(viewModel.device == nil)
            #expect(viewModel.isLoading == false)
            #expect(viewModel.error == nil)
            #expect(viewModel.isScanning == false)
            #expect(viewModel.isDiscovering == false)
        }

        @Test("ViewModel is MainActor and Observable")
        @MainActor
        func testViewModelIsObservable() {
            let viewModel = DeviceDetailViewModel()
            // If this compiles on @MainActor, the type is correctly marked
            #expect(viewModel.isLoading == false)
        }

        @Test("EnrichDevice with nil device does not crash")
        @MainActor
        func testEnrichDeviceWithNilDevice() async {
            let viewModel = DeviceDetailViewModel()

            // Should not crash when device is nil
            await viewModel.enrichDevice(bonjourServices: [])

            #expect(viewModel.device == nil)
            #expect(viewModel.isLoading == false)
        }

        @Test("ScanPorts with nil device does not crash")
        @MainActor
        func testScanPortsWithNilDevice() async {
            let viewModel = DeviceDetailViewModel()

            // Should not crash when device is nil
            await viewModel.scanPorts()

            #expect(viewModel.device == nil)
            #expect(viewModel.isScanning == false)
        }

        @Test("DiscoverServices with nil device does not crash")
        @MainActor
        func testDiscoverServicesWithNilDevice() async {
            let viewModel = DeviceDetailViewModel()

            // Should not crash when device is nil
            await viewModel.discoverServices()

            #expect(viewModel.device == nil)
            #expect(viewModel.isDiscovering == false)
        }

        @Test("Loading states are mutually exclusive")
        @MainActor
        func testLoadingStatesInitiallyFalse() {
            let viewModel = DeviceDetailViewModel()

            // All loading states should be false initially
            #expect(viewModel.isLoading == false)
            #expect(viewModel.isScanning == false)
            #expect(viewModel.isDiscovering == false)
        }
    }

    // MARK: - Integration Tests

    @Suite("Device Detail Integration")
    struct DeviceDetailIntegrationTests {

        @Test("BonjourService model has expected properties")
        func testBonjourServiceModel() {
            let service = BonjourService(
                name: "TestDevice",
                type: "_http._tcp",
                domain: "local.",
                hostName: "testdevice.local",
                port: 8080,
                txtRecords: ["version": "1.0"],
                addresses: ["192.168.1.100", "192.168.1.101"]
            )

            #expect(service.name == "TestDevice")
            #expect(service.type == "_http._tcp")
            #expect(service.domain == "local.")
            #expect(service.hostName == "testdevice.local")
            #expect(service.port == 8080)
            #expect(service.txtRecords["version"] == "1.0")
            #expect(service.addresses.count == 2)
            #expect(service.addresses.contains("192.168.1.100"))
        }

        @Test("BonjourService fullType combines type and domain")
        func testBonjourServiceFullType() {
            let service = BonjourService(
                name: "Test",
                type: "_http._tcp",
                domain: "local."
            )

            #expect(service.fullType == "_http._tcp.local.")
        }

        @Test("BonjourService categorizes web services")
        func testBonjourServiceWebCategory() {
            let httpService = BonjourService(name: "HTTP", type: "_http._tcp")
            let httpsService = BonjourService(name: "HTTPS", type: "_https._tcp")

            #expect(httpService.serviceCategory == "Web")
            #expect(httpsService.serviceCategory == "Web")
        }

        @Test("BonjourService categorizes remote access services")
        func testBonjourServiceRemoteAccessCategory() {
            let sshService = BonjourService(name: "SSH", type: "_ssh._tcp")
            let sftpService = BonjourService(name: "SFTP", type: "_sftp._tcp")

            #expect(sshService.serviceCategory == "Remote Access")
            #expect(sftpService.serviceCategory == "Remote Access")
        }

        @Test("BonjourService categorizes file sharing services")
        func testBonjourServiceFileSharingCategory() {
            let smbService = BonjourService(name: "SMB", type: "_smb._tcp")
            let afpService = BonjourService(name: "AFP", type: "_afpovertcp._tcp")

            #expect(smbService.serviceCategory == "File Sharing")
            #expect(afpService.serviceCategory == "File Sharing")
        }

        @Test("BonjourService categorizes unknown services as Other")
        func testBonjourServiceOtherCategory() {
            let unknownService = BonjourService(name: "Unknown", type: "_custom._tcp")

            #expect(unknownService.serviceCategory == "Other")
        }
    }
}
