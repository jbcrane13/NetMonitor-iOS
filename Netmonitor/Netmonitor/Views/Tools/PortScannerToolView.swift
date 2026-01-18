import SwiftUI

/// Port Scanner tool view for scanning open ports
struct PortScannerToolView: View {
    @State private var viewModel = PortScannerToolViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.sectionSpacing) {
                inputSection
                controlSection
                progressSection
                resultsSection
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.bottom, Theme.Layout.sectionSpacing)
        }
        .themedBackground()
        .navigationTitle("Port Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .accessibilityIdentifier("screen_portScannerTool")
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            ToolInputField(
                text: $viewModel.host,
                placeholder: "Enter hostname or IP address",
                icon: "door.left.hand.open",
                keyboardType: .URL
            )
            .accessibilityIdentifier("portScanner_input_host")

            // Port range picker
            HStack {
                Text("Port Range")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                Picker("Range", selection: $viewModel.portRange) {
                    ForEach(PortScannerToolViewModel.PortRange.allCases.filter { $0 != .custom }, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.accent)
                .accessibilityIdentifier("portScanner_picker_range")
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Control Section

    private var controlSection: some View {
        HStack(spacing: 12) {
            ToolRunButton(
                title: "Start Scan",
                icon: "play.fill",
                isRunning: viewModel.isRunning,
                stopTitle: "Stop Scan",
                action: {
                    if viewModel.isRunning {
                        viewModel.stopScan()
                    } else {
                        viewModel.startScan()
                    }
                }
            )
            .disabled(!viewModel.canStartScan && !viewModel.isRunning)
            .accessibilityIdentifier("portScanner_button_run")

            if !viewModel.results.isEmpty && !viewModel.isRunning {
                Button {
                    viewModel.clearResults()
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Layout.buttonCornerRadius)
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Layout.buttonCornerRadius)
                                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                        )
                }
                .accessibilityIdentifier("portScanner_button_clear")
            }
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private var progressSection: some View {
        if viewModel.isRunning {
            GlassCard {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.progress)
                        .tint(Theme.Colors.accent)

                    HStack {
                        Text("Scanning...")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        Spacer()

                        Text("\(viewModel.scannedCount) / \(viewModel.totalPorts)")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .accessibilityIdentifier("portScanner_progress")
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if !viewModel.results.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Open Ports")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Spacer()

                    Text("\(viewModel.openPorts.count) found")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.success)
                }

                if viewModel.openPorts.isEmpty {
                    GlassCard {
                        HStack {
                            Image(systemName: "checkmark.shield")
                                .font(.title2)
                                .foregroundStyle(Theme.Colors.success)

                            VStack(alignment: .leading) {
                                Text("No open ports found")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.Colors.textPrimary)
                                Text("All scanned ports are closed")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }

                            Spacer()
                        }
                    }
                } else {
                    GlassCard {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.openPorts.enumerated()), id: \.element.id) { index, result in
                                PortResultRow(result: result)

                                if index < viewModel.openPorts.count - 1 {
                                    Divider()
                                        .background(Theme.Colors.glassBorder)
                                        .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("portScanner_section_results")
        }
    }
}

// MARK: - Port Result Row

private struct PortResultRow: View {
    let result: PortScanResult

    var body: some View {
        HStack(spacing: 12) {
            // Port number badge
            Text("\(result.port)")
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 60, alignment: .leading)

            // Service info
            VStack(alignment: .leading, spacing: 2) {
                Text(result.serviceName ?? "Unknown")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                if let responseTime = result.responseTime {
                    Text(String(format: "%.0f ms", responseTime))
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            Spacer()

            // State badge
            Text(result.state.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(result.state == .open ? Theme.Colors.success : Theme.Colors.error)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill((result.state == .open ? Theme.Colors.success : Theme.Colors.error).opacity(0.2))
                )
        }
        .accessibilityIdentifier("portScanner_result_\(result.port)")
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PortScannerToolView()
    }
}
