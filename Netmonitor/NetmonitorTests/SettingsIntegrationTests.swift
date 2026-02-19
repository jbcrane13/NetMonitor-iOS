import Testing
import Foundation
@testable import Netmonitor

/// Integration tests verifying that SettingsViewModel read/write round-trips persist
/// correctly to UserDefaults. Each test saves the original value and restores it
/// via `defer` to prevent cross-test pollution. These complement the default-value
/// checks in ReleaseValidationTests by verifying the full write→persist→read cycle.
@Suite("Settings Persistence Integration Tests")
@MainActor
struct SettingsIntegrationTests {

    // MARK: - Network Tools Settings

    @Test("ping count write round-trip is readable by a new ViewModel instance")
    func pingCountRoundTrip() {
        let vm = SettingsViewModel()
        let original = vm.defaultPingCount
        defer { vm.defaultPingCount = original }

        vm.defaultPingCount = 8
        #expect(vm.defaultPingCount == 8)

        // A fresh instance reads the same persisted value
        let vm2 = SettingsViewModel()
        #expect(vm2.defaultPingCount == 8)
    }

    @Test("ping timeout write persists to UserDefaults key")
    func pingTimeoutPersistence() {
        let vm = SettingsViewModel()
        let original = vm.pingTimeout
        defer { vm.pingTimeout = original }

        vm.pingTimeout = 3.0
        #expect(vm.pingTimeout == 3.0)

        let saved = UserDefaults.standard.object(forKey: AppSettings.Keys.pingTimeout) as? Double
        #expect(saved == 3.0)
    }

    @Test("port scan timeout write persists to UserDefaults key")
    func portScanTimeoutPersistence() {
        let vm = SettingsViewModel()
        let original = vm.portScanTimeout
        defer { vm.portScanTimeout = original }

        vm.portScanTimeout = 5.0
        #expect(vm.portScanTimeout == 5.0)

        let saved = UserDefaults.standard.object(forKey: AppSettings.Keys.portScanTimeout) as? Double
        #expect(saved == 5.0)
    }

    @Test("DNS server string write persists to UserDefaults key")
    func dnsServerPersistence() {
        let vm = SettingsViewModel()
        let original = vm.dnsServer
        defer { vm.dnsServer = original }

        vm.dnsServer = "8.8.8.8"
        #expect(vm.dnsServer == "8.8.8.8")

        let saved = UserDefaults.standard.string(forKey: AppSettings.Keys.dnsServer)
        #expect(saved == "8.8.8.8")
    }

    // MARK: - Data Settings

    @Test("data retention days write persists to UserDefaults key")
    func dataRetentionPersistence() {
        let vm = SettingsViewModel()
        let original = vm.dataRetentionDays
        defer { vm.dataRetentionDays = original }

        vm.dataRetentionDays = 7
        #expect(vm.dataRetentionDays == 7)

        let saved = UserDefaults.standard.object(forKey: AppSettings.Keys.dataRetentionDays) as? Int
        #expect(saved == 7)
    }

    @Test("show detailed results toggle write persists false to UserDefaults key")
    func showDetailedResultsPersistence() {
        let vm = SettingsViewModel()
        let original = vm.showDetailedResults
        defer { vm.showDetailedResults = original }

        vm.showDetailedResults = false
        #expect(vm.showDetailedResults == false)

        let saved = UserDefaults.standard.object(forKey: AppSettings.Keys.showDetailedResults) as? Bool
        #expect(saved == false)
    }

    // MARK: - Monitoring Settings

    @Test("auto-refresh interval write persists to UserDefaults key")
    func autoRefreshIntervalPersistence() {
        let vm = SettingsViewModel()
        let original = vm.autoRefreshInterval
        defer { vm.autoRefreshInterval = original }

        vm.autoRefreshInterval = 30
        #expect(vm.autoRefreshInterval == 30)

        let saved = UserDefaults.standard.object(forKey: AppSettings.Keys.autoRefreshInterval) as? Int
        #expect(saved == 30)
    }

    @Test("background refresh enabled write persists false to UserDefaults key")
    func backgroundRefreshPersistence() {
        let vm = SettingsViewModel()
        let original = vm.backgroundRefreshEnabled
        defer { vm.backgroundRefreshEnabled = original }

        vm.backgroundRefreshEnabled = false
        #expect(vm.backgroundRefreshEnabled == false)

        let saved = UserDefaults.standard.object(forKey: AppSettings.Keys.backgroundRefreshEnabled) as? Bool
        #expect(saved == false)
    }

    // MARK: - Notification Settings

    @Test("high latency alert enabled write persists true to UserDefaults key")
    func highLatencyAlertEnabledPersistence() {
        let vm = SettingsViewModel()
        let original = vm.highLatencyAlertEnabled
        defer { vm.highLatencyAlertEnabled = original }

        vm.highLatencyAlertEnabled = true
        #expect(vm.highLatencyAlertEnabled == true)

        let saved = UserDefaults.standard.object(forKey: AppSettings.Keys.highLatencyAlertEnabled) as? Bool
        #expect(saved == true)
    }

    @Test("high latency threshold write persists to UserDefaults key")
    func highLatencyThresholdPersistence() {
        let vm = SettingsViewModel()
        let original = vm.highLatencyThreshold
        defer { vm.highLatencyThreshold = original }

        vm.highLatencyThreshold = 200
        #expect(vm.highLatencyThreshold == 200)

        let saved = UserDefaults.standard.object(forKey: AppSettings.Keys.highLatencyThreshold) as? Int
        #expect(saved == 200)
    }

    // MARK: - Appearance Settings

    @Test("accent color write round-trip persists via ThemeManager and is reflected in ViewModel")
    func accentColorPersistence() {
        let vm = SettingsViewModel()
        let original = vm.selectedAccentColor
        defer { vm.selectedAccentColor = original }

        vm.selectedAccentColor = "green"
        #expect(vm.selectedAccentColor == "green")
        #expect(ThemeManager.shared.selectedAccentColor == "green")
    }

    // MARK: - All-Defaults Validation

    @Test("SettingsViewModel reads correct defaults for all keys when UserDefaults has no stored values")
    func settingsViewModelDefaultsMatchExpected() {
        let keys: [String] = [
            AppSettings.Keys.defaultPingCount,
            AppSettings.Keys.pingTimeout,
            AppSettings.Keys.portScanTimeout,
            AppSettings.Keys.dnsServer,
            AppSettings.Keys.dataRetentionDays,
            AppSettings.Keys.showDetailedResults,
            AppSettings.Keys.autoRefreshInterval,
            AppSettings.Keys.backgroundRefreshEnabled,
            AppSettings.Keys.highLatencyAlertEnabled,
            AppSettings.Keys.highLatencyThreshold
        ]

        // Save originals, then remove all keys so ViewModel falls back to hardcoded defaults
        let originals: [String: Any] = Dictionary(
            uniqueKeysWithValues: keys.compactMap { key in
                guard let value = UserDefaults.standard.object(forKey: key) else { return nil }
                return (key, value)
            }
        )
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }

        defer {
            for key in keys {
                if let value = originals[key] {
                    UserDefaults.standard.set(value, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }

        let vm = SettingsViewModel()
        #expect(vm.defaultPingCount == 4)
        #expect(vm.pingTimeout == 5.0)
        #expect(vm.portScanTimeout == 2.0)
        #expect(vm.dnsServer == "")
        #expect(vm.dataRetentionDays == 30)
        #expect(vm.showDetailedResults == true)
        #expect(vm.autoRefreshInterval == 60)
        #expect(vm.backgroundRefreshEnabled == true)
        #expect(vm.highLatencyAlertEnabled == false)
        #expect(vm.highLatencyThreshold == 100)
    }
}
