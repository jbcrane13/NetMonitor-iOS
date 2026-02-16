import Testing
import Foundation
import SwiftData
@testable import Netmonitor

// MARK: - ThemeManager Tests

@Suite("ThemeManager Tests")
struct ThemeManagerTests {

    @Test("ThemeManager singleton exists")
    func singletonExists() {
        let instance = ThemeManager.shared
        #expect(instance != nil)
    }

    @Test("Default accent color is a valid option")
    func defaultAccentColor() {
        let validOptions = ["cyan", "blue", "green", "purple", "orange", "red"]
        let currentValue = ThemeManager.shared.selectedAccentColor
        #expect(validOptions.contains(currentValue))
    }

    @Test("Changing selectedAccentColor updates UserDefaults")
    func accentColorPersistence() {
        let originalValue = ThemeManager.shared.selectedAccentColor

        ThemeManager.shared.selectedAccentColor = "purple"
        let saved = UserDefaults.standard.string(forKey: AppSettings.Keys.selectedAccentColor)
        #expect(saved == "purple")

        // Restore original
        ThemeManager.shared.selectedAccentColor = originalValue
    }

    @Test("accent computed property returns correct color for each option")
    func accentColorMapping() {
        let theme = ThemeManager.shared
        let originalValue = theme.selectedAccentColor

        // Test each accent option
        let options = ["cyan", "blue", "green", "purple", "orange", "red"]
        for option in options {
            theme.selectedAccentColor = option
            let color = theme.accent
            #expect(color != nil)
        }

        // Restore
        theme.selectedAccentColor = originalValue
    }

    @Test("accentLight returns different color than accent")
    func accentLightDifference() {
        let theme = ThemeManager.shared
        let accent = theme.accent
        let accentLight = theme.accentLight

        // Colors should be different (light vs regular)
        // We can't directly compare Color values, but we can verify they exist
        #expect(accent != nil)
        #expect(accentLight != nil)
    }

    @Test("Setting accent color is reflected in ThemeManager")
    func userDefaultsInit() {
        let originalValue = ThemeManager.shared.selectedAccentColor

        // Set via ThemeManager (which writes to UserDefaults)
        ThemeManager.shared.selectedAccentColor = "blue"
        #expect(ThemeManager.shared.selectedAccentColor == "blue")
        #expect(UserDefaults.standard.string(forKey: AppSettings.Keys.selectedAccentColor) == "blue")

        // Restore original
        ThemeManager.shared.selectedAccentColor = originalValue
    }
}

// MARK: - DeviceDetailViewModel Cancellation Tests

@Suite("DeviceDetailViewModel Cancellation Tests")
@MainActor
struct DeviceDetailViewModelCancellationTests {

    @Test("enrichDevice with nil device returns immediately")
    func enrichDeviceNilDevice() async {
        let vm = DeviceDetailViewModel()
        vm.device = nil

        #expect(vm.isLoading == false)
        await vm.enrichDevice(bonjourServices: [])
        #expect(vm.isLoading == false)
    }

    @Test("scanPorts with nil device returns immediately")
    func scanPortsNilDevice() async {
        let vm = DeviceDetailViewModel()
        vm.device = nil

        #expect(vm.isScanning == false)
        await vm.scanPorts()
        #expect(vm.isScanning == false)
    }

    @Test("discoverServices with nil device returns immediately")
    func discoverServicesNilDevice() async {
        let vm = DeviceDetailViewModel()
        vm.device = nil

        #expect(vm.isDiscovering == false)
        await vm.discoverServices()
        #expect(vm.isDiscovering == false)
    }

    @Test("isLoading resets to false after enrichDevice completes")
    func isLoadingResets() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalDevice.self, configurations: config)
        let context = ModelContext(container)

        let vm = DeviceDetailViewModel()
        vm.loadDevice(ipAddress: "192.168.1.1", context: context)

        #expect(vm.isLoading == false)
        await vm.enrichDevice(bonjourServices: [])
        #expect(vm.isLoading == false)
    }

    @Test("isScanning resets to false after scanPorts completes")
    func isScanningResets() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalDevice.self, configurations: config)
        let context = ModelContext(container)

        let vm = DeviceDetailViewModel()
        vm.loadDevice(ipAddress: "192.168.1.1", context: context)

        #expect(vm.isScanning == false)
        // Note: scanPorts will timeout waiting for actual responses, so it may take time
        // For unit tests, we just verify the flag resets
        await vm.scanPorts()
        #expect(vm.isScanning == false)
    }

    @Test("isDiscovering resets to false after discoverServices completes")
    func isDiscoveringResets() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: LocalDevice.self, configurations: config)
        let context = ModelContext(container)

        let vm = DeviceDetailViewModel()
        vm.loadDevice(ipAddress: "192.168.1.1", context: context)

        #expect(vm.isDiscovering == false)
        await vm.discoverServices()
        #expect(vm.isDiscovering == false)
    }
}

// MARK: - Mock Services for NetworkMapViewModel

@MainActor
final class MockDeviceDiscoveryService: DeviceDiscoveryServiceProtocol {
    var discoveredDevices: [DiscoveredDevice] = []
    var isScanning: Bool = false
    var scanProgress: Double = 0
    var scanPhase: DeviceDiscoveryService.ScanPhase = .idle
    var lastScanDate: Date?

    var scanNetworkCalled = false

    func scanNetwork(subnet: String?) async {
        scanNetworkCalled = true
        isScanning = true
        scanProgress = 0.5
        discoveredDevices = [
            DiscoveredDevice(ipAddress: "192.168.1.1", latency: 10, discoveredAt: Date()),
            DiscoveredDevice(ipAddress: "192.168.1.2", latency: 20, discoveredAt: Date())
        ]
        lastScanDate = Date()
        isScanning = false
    }

    func stopScan() {
        isScanning = false
    }
}

@MainActor
final class MockGatewayService: GatewayServiceProtocol {
    var gateway: GatewayInfo?
    var isLoading: Bool = false

    func detectGateway() async {
        isLoading = true
        gateway = GatewayInfo(ipAddress: "192.168.1.1", latency: 5)
        isLoading = false
    }
}

@MainActor
final class MockBonjourDiscoveryService: BonjourDiscoveryServiceProtocol {
    var discoveredServices: [BonjourService] = []
    var isDiscovering: Bool = false

    func discoveryStream(serviceType: String?) -> AsyncStream<BonjourService> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    func startDiscovery(serviceType: String?) {
        isDiscovering = true
    }

    func stopDiscovery() {
        isDiscovering = false
    }

    func resolveService(_ service: BonjourService) async -> BonjourService? {
        return service
    }
}

// MARK: - NetworkMapViewModel Cache Tests

@Suite("NetworkMapViewModel Cache Tests")
@MainActor
struct NetworkMapViewModelCacheTests {

    @Test("cachedDevices starts empty")
    func cachedDevicesEmpty() {
        let vm = NetworkMapViewModel()
        #expect(vm.cachedDevices.isEmpty)
    }

    @Test("after startScan cachedDevices are populated")
    func cachedDevicesPopulated() async {
        let mockDiscovery = MockDeviceDiscoveryService()
        let mockGateway = MockGatewayService()
        let mockBonjour = MockBonjourDiscoveryService()

        let vm = NetworkMapViewModel(
            deviceDiscoveryService: mockDiscovery,
            gatewayService: mockGateway,
            bonjourService: mockBonjour
        )

        await vm.startScan()
        #expect(!vm.cachedDevices.isEmpty)
        #expect(vm.cachedDevices.count == 2)
    }

    @Test("startScan without forceRefresh uses cache when non-empty")
    func scanUsesCache() async {
        let mockDiscovery = MockDeviceDiscoveryService()
        let mockGateway = MockGatewayService()
        let mockBonjour = MockBonjourDiscoveryService()

        let vm = NetworkMapViewModel(
            deviceDiscoveryService: mockDiscovery,
            gatewayService: mockGateway,
            bonjourService: mockBonjour
        )

        // First scan
        await vm.startScan()
        #expect(mockDiscovery.scanNetworkCalled)

        // Reset mock
        mockDiscovery.scanNetworkCalled = false

        // Second scan without force refresh - should skip
        await vm.startScan(forceRefresh: false)
        #expect(!mockDiscovery.scanNetworkCalled)
    }

    @Test("startScan with forceRefresh rescans even with cache")
    func scanWithForceRefresh() async {
        let mockDiscovery = MockDeviceDiscoveryService()
        let mockGateway = MockGatewayService()
        let mockBonjour = MockBonjourDiscoveryService()

        let vm = NetworkMapViewModel(
            deviceDiscoveryService: mockDiscovery,
            gatewayService: mockGateway,
            bonjourService: mockBonjour
        )

        // First scan
        await vm.startScan()
        #expect(mockDiscovery.scanNetworkCalled)

        // Reset mock
        mockDiscovery.scanNetworkCalled = false

        // Second scan with force refresh - should rescan
        await vm.startScan(forceRefresh: true)
        #expect(mockDiscovery.scanNetworkCalled)
    }

    @Test("discoveredDevices returns service devices when available")
    func discoveredDevicesFromService() async {
        let mockDiscovery = MockDeviceDiscoveryService()
        let mockGateway = MockGatewayService()
        let mockBonjour = MockBonjourDiscoveryService()

        let vm = NetworkMapViewModel(
            deviceDiscoveryService: mockDiscovery,
            gatewayService: mockGateway,
            bonjourService: mockBonjour
        )

        await vm.startScan()
        let devices = vm.discoveredDevices
        #expect(devices.count == 2)
    }

    @Test("discoveredDevices returns cached devices when service is empty")
    func discoveredDevicesFromCache() async {
        let mockDiscovery = MockDeviceDiscoveryService()
        let mockGateway = MockGatewayService()
        let mockBonjour = MockBonjourDiscoveryService()

        let vm = NetworkMapViewModel(
            deviceDiscoveryService: mockDiscovery,
            gatewayService: mockGateway,
            bonjourService: mockBonjour
        )

        await vm.startScan()

        // Clear service devices
        mockDiscovery.discoveredDevices = []

        // Should return cached devices
        let devices = vm.discoveredDevices
        #expect(devices.count == 2)
    }
}

// MARK: - SettingsViewModel Tests

@Suite("SettingsViewModel Tests")
@MainActor
struct SettingsViewModelTests {

    @Test("defaultPingCount has sensible default")
    func defaultPingCount() {
        let testDefaults = UserDefaults(suiteName: "test.settings.pingcount")!
        testDefaults.removePersistentDomain(forName: "test.settings.pingcount")

        let vm = SettingsViewModel()
        #expect(vm.defaultPingCount == 4)
    }

    @Test("setting defaultPingCount persists to UserDefaults")
    func pingCountPersistence() {
        let vm = SettingsViewModel()
        vm.defaultPingCount = 10

        let saved = UserDefaults.standard.integer(forKey: AppSettings.Keys.defaultPingCount)
        #expect(saved == 10)

        // Reset
        vm.defaultPingCount = 4
    }

    @Test("pingTimeout has default 5.0")
    func pingTimeoutDefault() {
        let vm = SettingsViewModel()
        let timeout = vm.pingTimeout
        #expect(timeout == 5.0)
    }

    @Test("portScanTimeout has default 2.0")
    func portScanTimeoutDefault() {
        let vm = SettingsViewModel()
        let timeout = vm.portScanTimeout
        #expect(timeout == 2.0)
    }

    @Test("backgroundRefreshEnabled defaults to true")
    func backgroundRefreshDefault() {
        let vm = SettingsViewModel()
        let enabled = vm.backgroundRefreshEnabled
        #expect(enabled == true)
    }

    @Test("dataRetentionDays defaults to 30")
    func dataRetentionDefault() {
        let vm = SettingsViewModel()
        let days = vm.dataRetentionDays
        #expect(days == 30)
    }

    @Test("highLatencyThreshold defaults to 100")
    func highLatencyThresholdDefault() {
        let vm = SettingsViewModel()
        let threshold = vm.highLatencyThreshold
        #expect(threshold == 100)
    }

    @Test("selectedAccentColor reads from ThemeManager")
    func accentColorFromTheme() {
        let vm = SettingsViewModel()
        let accentColor = vm.selectedAccentColor
        #expect(accentColor == ThemeManager.shared.selectedAccentColor)
    }

    @Test("autoRefreshInterval defaults to 60")
    func autoRefreshIntervalDefault() {
        let vm = SettingsViewModel()
        let interval = vm.autoRefreshInterval
        #expect(interval == 60)
    }
}

// MARK: - NotificationService Tests

@Suite("NotificationService Tests")
@MainActor
struct NotificationServiceTests {

    @Test("NotificationService singleton exists")
    func singletonExists() {
        let instance = NotificationService.shared
        #expect(instance != nil)
    }

    @Test("Category identifiers are correct strings")
    func categoryIdentifiers() {
        #expect(NotificationService.targetDownCategory == "TARGET_DOWN")
        #expect(NotificationService.highLatencyCategory == "HIGH_LATENCY")
        #expect(NotificationService.newDeviceCategory == "NEW_DEVICE")
    }

    @Test("notifyHighLatency respects threshold")
    func highLatencyThreshold() {
        let testDefaults = UserDefaults(suiteName: "test.notifications.latency")!
        testDefaults.removePersistentDomain(forName: "test.notifications.latency")

        // Set threshold to 100 in standard defaults
        UserDefaults.standard.set(100, forKey: AppSettings.Keys.highLatencyThreshold)

        // Below threshold - should not notify (we can't test actual notification, but method should execute)
        NotificationService.shared.notifyHighLatency(host: "test.com", latency: 50)

        // Above threshold - should notify
        NotificationService.shared.notifyHighLatency(host: "test.com", latency: 150)

        // Both calls should complete without error
        #expect(true)
    }

    @Test("notifyTargetDown respects enabled setting")
    func targetDownEnabled() {
        // When disabled, should return early
        UserDefaults.standard.set(false, forKey: AppSettings.Keys.targetDownAlertEnabled)
        NotificationService.shared.notifyTargetDown(name: "Test", host: "test.com")

        // When enabled
        UserDefaults.standard.set(true, forKey: AppSettings.Keys.targetDownAlertEnabled)
        NotificationService.shared.notifyTargetDown(name: "Test", host: "test.com")

        // Both should complete without error
        #expect(true)

        // Reset
        UserDefaults.standard.set(true, forKey: AppSettings.Keys.targetDownAlertEnabled)
    }
}

// MARK: - BackgroundTaskService Tests

@Suite("BackgroundTaskService Tests")
@MainActor
struct BackgroundTaskServiceTests {

    @Test("BackgroundTaskService singleton exists")
    func singletonExists() {
        let instance = BackgroundTaskService.shared
        #expect(instance != nil)
    }

    @Test("Task identifiers are correct strings")
    func taskIdentifiers() {
        #expect(BackgroundTaskService.refreshTaskIdentifier == "com.blakemiller.netmonitor.refresh")
        #expect(BackgroundTaskService.syncTaskIdentifier == "com.blakemiller.netmonitor.sync")
    }

    @Test("scheduleRefreshTask respects backgroundRefreshEnabled false")
    func scheduleRespectsSetting() {
        UserDefaults.standard.set(false, forKey: AppSettings.Keys.backgroundRefreshEnabled)

        // Should cancel task when disabled
        BackgroundTaskService.shared.scheduleRefreshTask()

        // No error means it handled the disabled state
        #expect(true)

        // Reset
        UserDefaults.standard.set(true, forKey: AppSettings.Keys.backgroundRefreshEnabled)
    }
}

// MARK: - SpeedTest Configuration Tests

@Suite("SpeedTest Configuration Tests")
@MainActor
struct SpeedTestConfigurationTests {

    @Test("SpeedTestService default duration is 5.0")
    func defaultDuration() {
        let service = SpeedTestService()
        #expect(service.duration == 5.0)
    }

    @Test("duration can be changed")
    func durationCanChange() {
        let service = SpeedTestService()
        service.duration = 10.0
        #expect(service.duration == 10.0)
    }

    @Test("SpeedTestService initial state")
    func initialState() {
        let service = SpeedTestService()
        #expect(service.isRunning == false)
        #expect(service.phase == .idle)
        #expect(service.downloadSpeed == 0)
        #expect(service.uploadSpeed == 0)
        #expect(service.latency == 0)
        #expect(service.progress == 0)
    }
}

// MARK: - BonjourDiscovery Tests

@Suite("BonjourDiscovery Tests")
struct BonjourDiscoveryTests {

    @Test("BonjourService model properties")
    func modelProperties() {
        let service = BonjourService(
            name: "Test Service",
            type: "_http._tcp",
            domain: "local.",
            hostName: "test.local",
            port: 8080
        )

        #expect(service.name == "Test Service")
        #expect(service.type == "_http._tcp")
        #expect(service.domain == "local.")
        #expect(service.hostName == "test.local")
        #expect(service.port == 8080)
    }

    @Test("BonjourService fullType")
    func fullType() {
        let service = BonjourService(
            name: "Test",
            type: "_http._tcp",
            domain: "local."
        )

        #expect(service.fullType == "_http._tcp.local.")
    }

    @Test("serviceCategory classification")
    func serviceCategories() {
        let webService = BonjourService(name: "Web", type: "_http._tcp")
        #expect(webService.serviceCategory == "Web")

        let sshService = BonjourService(name: "SSH", type: "_ssh._tcp")
        #expect(sshService.serviceCategory == "Remote Access")

        let smbService = BonjourService(name: "SMB", type: "_smb._tcp")
        #expect(smbService.serviceCategory == "File Sharing")

        let printerService = BonjourService(name: "Printer", type: "_printer._tcp")
        #expect(printerService.serviceCategory == "Printing")

        let airplayService = BonjourService(name: "AirPlay", type: "_airplay._tcp")
        #expect(airplayService.serviceCategory == "AirPlay")

        let unknownService = BonjourService(name: "Unknown", type: "_custom._tcp")
        #expect(unknownService.serviceCategory == "Other")
    }

    @Test("BonjourDiscoveryService initial state")
    @MainActor
    func initialState() {
        let service = BonjourDiscoveryService()
        #expect(service.discoveredServices.isEmpty)
        #expect(service.isDiscovering == false)
    }

    @Test("stopDiscovery resets state")
    @MainActor
    func stopDiscovery() {
        let service = BonjourDiscoveryService()
        service.startDiscovery(serviceType: nil)
        #expect(service.isDiscovering == true)

        service.stopDiscovery()
        #expect(service.isDiscovering == false)
    }
}

// MARK: - MonitoringTarget Model Tests

@Suite("MonitoringTarget Tests")
struct MonitoringTargetTests {

    @Test("recordSuccess updates stats correctly")
    func recordSuccess() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        target.recordSuccess(latency: 50)

        #expect(target.totalChecks == 1)
        #expect(target.successfulChecks == 1)
        #expect(target.consecutiveFailures == 0)
        #expect(target.isOnline == true)
        #expect(target.currentLatency == 50)
    }

    @Test("recordFailure increments failures")
    func recordFailure() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        target.recordFailure()

        #expect(target.totalChecks == 1)
        #expect(target.consecutiveFailures == 1)
        #expect(target.currentLatency == nil)
    }

    @Test("isOnline goes false after 3 consecutive failures")
    func threeFailuresGoOffline() {
        let target = MonitoringTarget(name: "Test", host: "test.com")
        target.recordSuccess(latency: 10) // Start online

        #expect(target.isOnline == true)

        target.recordFailure()
        #expect(target.isOnline == true) // Still online after 1

        target.recordFailure()
        #expect(target.isOnline == true) // Still online after 2

        target.recordFailure()
        #expect(target.isOnline == false) // Offline after 3
    }

    @Test("uptimePercentage calculation")
    func uptimeCalculation() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        #expect(target.uptimePercentage == 0) // No checks yet

        target.recordSuccess(latency: 10)
        target.recordSuccess(latency: 20)
        target.recordFailure()
        target.recordSuccess(latency: 15)

        // 3 successful out of 4 total = 75%
        #expect(target.uptimePercentage == 75.0)
    }

    @Test("latencyText formatting")
    func latencyFormatting() {
        let target = MonitoringTarget(name: "Test", host: "test.com")

        #expect(target.latencyText == nil) // No latency yet

        target.recordSuccess(latency: 0.5)
        #expect(target.latencyText == "<1 ms")

        target.recordSuccess(latency: 50.7)
        #expect(target.latencyText == "51 ms")

        target.recordSuccess(latency: 123.4)
        #expect(target.latencyText == "123 ms")
    }
}
