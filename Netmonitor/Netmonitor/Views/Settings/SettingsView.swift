import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var showingClearHistoryAlert = false

    var body: some View {
        List {
            // MARK: - Network Tools Section
            Section {
                HStack {
                    Text("Ping Count")
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Stepper("\(viewModel.defaultPingCount)",
                            value: $viewModel.defaultPingCount,
                            in: 1...50)
                        .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityIdentifier("settings_stepper_pingCount")

                HStack {
                    Text("Ping Timeout")
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Stepper("\(Int(viewModel.pingTimeout))s",
                            value: $viewModel.pingTimeout,
                            in: 1...30,
                            step: 1)
                        .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityIdentifier("settings_stepper_pingTimeout")

                HStack {
                    Text("Port Scan Timeout")
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Stepper(String(format: "%.1fs", viewModel.portScanTimeout),
                            value: $viewModel.portScanTimeout,
                            in: 0.5...10.0,
                            step: 0.5)
                        .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityIdentifier("settings_stepper_portScanTimeout")

                VStack(alignment: .leading, spacing: 8) {
                    Text("DNS Server")
                        .foregroundStyle(Theme.Colors.textPrimary)
                    TextField("Leave empty for system DNS", text: $viewModel.dnsServer)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .accessibilityIdentifier("settings_textfield_dnsServer")
                }
            } header: {
                Text("Network Tools")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .listRowBackground(Theme.Colors.glassBackground)

            // MARK: - Data & Privacy Section
            Section {
                Picker("Data Retention", selection: $viewModel.dataRetentionDays) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityIdentifier("settings_picker_dataRetention")

                Toggle(isOn: $viewModel.showDetailedResults) {
                    Text("Show Detailed Results")
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .tint(Theme.Colors.accent)
                .accessibilityIdentifier("settings_toggle_showDetailedResults")

                Button {
                    showingClearHistoryAlert = true
                } label: {
                    HStack {
                        Text("Clear History")
                            .foregroundStyle(Theme.Colors.error)
                        Spacer()
                        Image(systemName: "trash")
                            .foregroundStyle(Theme.Colors.error)
                    }
                }
                .accessibilityIdentifier("settings_button_clearHistory")
            } header: {
                Text("Data & Privacy")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .listRowBackground(Theme.Colors.glassBackground)

            // MARK: - About Section
            Section {
                HStack {
                    Text("App Version")
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(viewModel.appVersion)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .monospacedDigit()
                }
                .accessibilityIdentifier("settings_row_appVersion")

                HStack {
                    Text("Build Number")
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(viewModel.buildNumber)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .monospacedDigit()
                }
                .accessibilityIdentifier("settings_row_buildNumber")

                HStack {
                    Text("iOS Version")
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Text(viewModel.iosVersion)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .monospacedDigit()
                }
                .accessibilityIdentifier("settings_row_iosVersion")
            } header: {
                Text("About")
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .listRowBackground(Theme.Colors.glassBackground)
        }
        .scrollContentBackground(.hidden)
        .themedBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Clear History", isPresented: $showingClearHistoryAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearAllHistory(modelContext: modelContext)
            }
        } message: {
            Text("This will permanently delete all tool results and speed test history. This action cannot be undone.")
        }
        .accessibilityIdentifier("screen_settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .modelContainer(for: [
                PairedMac.self,
                LocalDevice.self,
                MonitoringTarget.self,
                ToolResult.self,
                SpeedTestResult.self
            ])
    }
}
