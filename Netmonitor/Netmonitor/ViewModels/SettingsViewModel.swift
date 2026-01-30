import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Network Tools Settings
    // Use UserDefaults directly since @AppStorage conflicts with @Observable
    private let defaults = UserDefaults.standard

    var defaultPingCount: Int {
        get { defaults.object(forKey: "defaultPingCount") as? Int ?? 4 }
        set { defaults.set(newValue, forKey: "defaultPingCount") }
    }

    var pingTimeout: Double {
        get { defaults.object(forKey: "pingTimeout") as? Double ?? 5.0 }
        set { defaults.set(newValue, forKey: "pingTimeout") }
    }

    var portScanTimeout: Double {
        get { defaults.object(forKey: "portScanTimeout") as? Double ?? 2.0 }
        set { defaults.set(newValue, forKey: "portScanTimeout") }
    }

    var dnsServer: String {
        get { defaults.string(forKey: "dnsServer") ?? "" }
        set { defaults.set(newValue, forKey: "dnsServer") }
    }

    // MARK: - Data Settings
    var dataRetentionDays: Int {
        get { defaults.object(forKey: "dataRetentionDays") as? Int ?? 30 }
        set { defaults.set(newValue, forKey: "dataRetentionDays") }
    }

    var showDetailedResults: Bool {
        get { defaults.object(forKey: "showDetailedResults") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showDetailedResults") }
    }

    // MARK: - Monitoring Settings
    var autoRefreshInterval: Int {
        get { defaults.object(forKey: "autoRefreshInterval") as? Int ?? 60 }
        set { defaults.set(newValue, forKey: "autoRefreshInterval") }
    }

    var backgroundRefreshEnabled: Bool {
        get { defaults.object(forKey: "backgroundRefreshEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "backgroundRefreshEnabled") }
    }

    // MARK: - Notification Settings
    var targetDownAlertEnabled: Bool {
        get { defaults.object(forKey: "targetDownAlertEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "targetDownAlertEnabled") }
    }

    var highLatencyThreshold: Int {
        get { defaults.object(forKey: "highLatencyThreshold") as? Int ?? 100 }
        set { defaults.set(newValue, forKey: "highLatencyThreshold") }
    }

    var newDeviceAlertEnabled: Bool {
        get { defaults.object(forKey: "newDeviceAlertEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "newDeviceAlertEnabled") }
    }

    // MARK: - Appearance Settings
    var selectedTheme: String {
        get { defaults.string(forKey: "selectedTheme") ?? "system" }
        set { defaults.set(newValue, forKey: "selectedTheme") }
    }

    var selectedAccentColor: String {
        get { defaults.string(forKey: "selectedAccentColor") ?? "cyan" }
        set { defaults.set(newValue, forKey: "selectedAccentColor") }
    }

    // MARK: - App Info
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var iosVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    // MARK: - Data Management
    func clearAllHistory(modelContext: ModelContext) {
        do {
            try modelContext.delete(model: ToolResult.self)
        } catch {
            print("Failed to delete tool results: \(error)")
        }

        do {
            try modelContext.delete(model: SpeedTestResult.self)
        } catch {
            print("Failed to delete speed test results: \(error)")
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save after clearing history: \(error)")
        }
    }
}
