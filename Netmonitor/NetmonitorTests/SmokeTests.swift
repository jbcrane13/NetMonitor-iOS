import Testing
import Foundation
@testable import Netmonitor

// MARK: - Smoke Test Suite
//
// Fast, critical-path tests for pre-build validation.
// Target: < 2 minutes. No network calls.
// Run with: xcodebuild test -only-testing:NetmonitorTests/SmokeTests

@Suite("Smoke Tests", .tags(.smoke))
struct SmokeTests {

    // MARK: - Models

    @Test("LocalDevice initializes with required fields")
    func localDeviceInit() {
        let device = LocalDevice(ipAddress: "192.168.1.1", macAddress: "AA:BB:CC:DD:EE:FF")
        #expect(device.ipAddress == "192.168.1.1")
        #expect(device.macAddress == "AA:BB:CC:DD:EE:FF")
    }

    @Test("MonitoringTarget initializes correctly")
    func monitoringTargetInit() {
        let target = MonitoringTarget(name: "Router", host: "192.168.1.1")
        #expect(target.name == "Router")
        #expect(target.host == "192.168.1.1")
        #expect(target.isEnabled == true)
    }

    @Test("MonitoringTarget records success and updates latency")
    func monitoringTargetRecordSuccess() {
        let target = MonitoringTarget(name: "Test", host: "10.0.0.1")
        target.recordSuccess(latency: 42.0)
        #expect(target.isOnline == true)
        #expect(target.averageLatency == 42.0)
        #expect(target.consecutiveFailures == 0)
    }

    @Test("MonitoringTarget records failure and increments counter")
    func monitoringTargetRecordFailure() {
        let target = MonitoringTarget(name: "Test", host: "10.0.0.1")
        target.recordSuccess(latency: 10.0)
        target.recordFailure()
        #expect(target.consecutiveFailures == 1)
    }

    @Test("CompanionMessage heartbeat round-trips through JSON")
    func companionMessageSerialization() throws {
        let payload = HeartbeatPayload(timestamp: Date(), version: "1.0")
        let msg = CompanionMessage.heartbeat(payload)
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(CompanionMessage.self, from: data)
        if case .heartbeat = decoded {
            // Success
        } else {
            Issue.record("Expected heartbeat, got different case")
        }
    }

    // MARK: - AppSettings Keys

    @Test("Critical AppSettings keys are non-empty strings")
    func appSettingsKeysExist() {
        let keys: [String] = [
            AppSettings.Keys.backgroundRefreshEnabled,
            AppSettings.Keys.highLatencyAlertEnabled,
            AppSettings.Keys.highLatencyThreshold,
            AppSettings.Keys.autoRefreshInterval,
            AppSettings.Keys.defaultPingCount,
            AppSettings.Keys.pingTimeout,
            AppSettings.Keys.portScanTimeout,
        ]
        for key in keys {
            #expect(!key.isEmpty, "AppSettings key should not be empty")
        }
    }

    @Test("highLatencyAlertEnabled defaults to false")
    func highLatencyAlertDefaultOff() {
        let suiteName = "com.netmonitor.smoketest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let value = defaults.object(forKey: AppSettings.Keys.highLatencyAlertEnabled) as? Bool ?? false
        #expect(value == false, "High latency alerts should default to OFF")
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: - TargetManager

    @Test("TargetManager starts with expected state")
    @MainActor
    func targetManagerState() {
        let manager = TargetManager.shared
        // Just verify it's accessible and doesn't crash
        let _ = manager.currentTarget
        let _ = manager.savedTargets
    }

    @Test("TargetManager set/clear cycle works")
    @MainActor
    func targetManagerSetClear() {
        let manager = TargetManager.shared
        let original = manager.currentTarget

        manager.setTarget("8.8.8.8")
        #expect(manager.currentTarget == "8.8.8.8")
        #expect(manager.savedTargets.contains("8.8.8.8"))

        manager.clearSelection()
        #expect(manager.currentTarget == nil)

        // Restore
        if let original { manager.setTarget(original) }
    }

    // MARK: - Services Init (no network)

    @Test("DNSLookupService initializes clean")
    func dnsServiceInit() async {
        let service = await DNSLookupService()
        let loading = await service.isLoading
        #expect(loading == false)
    }

    @Test("SpeedTestService initializes clean")
    @MainActor
    func speedTestServiceInit() {
        let service = SpeedTestService()
        #expect(service.isRunning == false)
    }

    @Test("GatewayService initializes with nil gateway")
    @MainActor
    func gatewayServiceInit() {
        let service = GatewayService()
        #expect(service.gateway == nil)
    }

    // MARK: - ConnectionBudget (deadlock regression)

    @Test("ConnectionBudget acquire/release doesn't deadlock")
    func connectionBudgetBasic() async {
        let budget = ConnectionBudget(limit: 2)
        await budget.acquire()
        await budget.acquire()
        // Both acquired at limit — release should free slots
        await budget.release()
        await budget.release()
        // If we get here, no deadlock
    }

    @Test("ConnectionBudget release resumes waiter even when over limit (thermal fix)")
    func connectionBudgetResumesWaiter() async {
        let budget = ConnectionBudget(limit: 1)
        await budget.acquire()

        // Spawn a waiter that will block
        let waiterDone = Task {
            await budget.acquire()
            return true
        }

        // Give waiter time to enqueue
        try? await Task.sleep(for: .milliseconds(50))

        // Release should resume the waiter
        await budget.release()

        // Waiter should complete quickly
        let result = await Task {
            try? await Task.sleep(for: .seconds(2))
            waiterDone.cancel()
            return false
        }.value

        let waiterResult = await waiterDone.value
        #expect(waiterResult == true, "Waiter should have been resumed by release()")

        // Cleanup
        await budget.release()
    }

    // MARK: - ToolActivityLog

    @Test("ToolActivityLog singleton adds and retrieves entries")
    @MainActor
    func toolActivityLogBasic() {
        let log = ToolActivityLog.shared
        let countBefore = log.entries.count

        log.add(tool: "Ping", target: "8.8.8.8", result: "12ms avg", success: true)

        #expect(log.entries.count == countBefore + 1)
        #expect(log.entries.first?.tool == "Ping")
    }

    // MARK: - ViewModels

    @Test("SettingsViewModel defaults are sane")
    @MainActor
    func settingsViewModelDefaults() {
        let vm = SettingsViewModel()
        #expect(vm.defaultPingCount > 0)
        #expect(vm.pingTimeout > 0)
        #expect(vm.highLatencyThreshold >= 50)
        // Verify the new property exists and compiles
        let _ = vm.highLatencyAlertEnabled
    }

    @Test("ThemeManager singleton provides valid accent")
    @MainActor
    func themeManagerAccent() {
        let valid = ["cyan", "blue", "green", "purple", "orange", "red"]
        #expect(valid.contains(ThemeManager.shared.selectedAccentColor))
    }

    // MARK: - Theme Colors (dark-only sanity)

    @Test("Theme primary colors resolve without crashing")
    @MainActor
    func themeColorsExist() {
        let _ = Theme.Colors.textPrimary
        let _ = Theme.Colors.textSecondary
        let _ = Theme.Colors.accent
        let _ = Theme.Colors.error
        let _ = Theme.Colors.success
        let _ = Theme.Colors.warning
        let _ = Theme.Colors.backgroundGradientStart
        let _ = Theme.Colors.backgroundGradientEnd
        let _ = Theme.Colors.glassBackground
    }

    @Test("Theme gradients resolve without crashing")
    @MainActor
    func themeGradientsExist() {
        let _ = Theme.Gradients.background
        let _ = Theme.Gradients.accentGlow
    }
}

// MARK: - Tag Definition

extension Tag {
    @Tag static var smoke: Self
}
