import SwiftUI

/// Ping tool view for testing host reachability
struct PingToolView: View {
    @State private var viewModel = PingToolViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.sectionSpacing) {
                inputSection
                controlSection
                resultsSection
                statisticsSection
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.bottom, Theme.Layout.sectionSpacing)
        }
        .themedBackground()
        .navigationTitle("Ping")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .accessibilityIdentifier("screen_pingTool")
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
                icon: "network",
                keyboardType: .URL,
                onSubmit: {
                    if viewModel.canStartPing {
                        viewModel.startPing()
                    }
                }
            )
            .accessibilityIdentifier("pingTool_input_host")

            // Ping count picker
            HStack {
                Text("Ping Count")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                Picker("Count", selection: $viewModel.pingCount) {
                    ForEach(viewModel.availablePingCounts, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.accent)
                .accessibilityIdentifier("pingTool_picker_count")
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Control Section

    private var controlSection: some View {
        HStack(spacing: 12) {
            ToolRunButton(
                title: "Start Ping",
                icon: "play.fill",
                isRunning: viewModel.isRunning,
                stopTitle: "Stop Ping",
                action: {
                    if viewModel.isRunning {
                        viewModel.stopPing()
                    } else {
                        viewModel.startPing()
                    }
                }
            )
            .disabled(!viewModel.canStartPing && !viewModel.isRunning)
            .accessibilityIdentifier("pingTool_button_run")

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
                .accessibilityIdentifier("pingTool_button_clear")
            }
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if !viewModel.results.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Results")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Spacer()

                    Text("\(viewModel.results.count) of \(viewModel.pingCount)")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                GlassCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, result in
                            PingResultRow(result: result)

                            if index < viewModel.results.count - 1 {
                                Divider()
                                    .background(Theme.Colors.glassBorder)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("pingTool_section_results")
        }
    }

    // MARK: - Statistics Section

    @ViewBuilder
    private var statisticsSection: some View {
        if let stats = viewModel.statistics {
            ToolStatisticsCard(
                title: "Ping Statistics",
                icon: "chart.bar",
                statistics: [
                    ToolStatistic(
                        label: "Min",
                        value: String(format: "%.1f ms", stats.minTime),
                        valueColor: Theme.Colors.success
                    ),
                    ToolStatistic(
                        label: "Avg",
                        value: String(format: "%.1f ms", stats.avgTime)
                    ),
                    ToolStatistic(
                        label: "Max",
                        value: String(format: "%.1f ms", stats.maxTime),
                        valueColor: Theme.Colors.warning
                    )
                ]
            )
            .accessibilityIdentifier("pingTool_card_statistics")

            ToolStatisticsCard(
                title: "Packet Statistics",
                icon: "arrow.up.arrow.down",
                statistics: [
                    ToolStatistic(
                        label: "Sent",
                        value: "\(stats.transmitted)",
                        icon: "arrow.up"
                    ),
                    ToolStatistic(
                        label: "Received",
                        value: "\(stats.received)",
                        icon: "arrow.down"
                    ),
                    ToolStatistic(
                        label: "Loss",
                        value: stats.packetLossText,
                        icon: "xmark",
                        valueColor: stats.packetLoss > 0 ? Theme.Colors.error : Theme.Colors.success
                    )
                ]
            )
            .accessibilityIdentifier("pingTool_card_packets")
        }
    }
}

// MARK: - Ping Result Row

private struct PingResultRow: View {
    let result: PingResult

    var body: some View {
        HStack(spacing: 12) {
            // Sequence number
            Text("#\(result.sequence)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 30, alignment: .leading)

            // IP/Host info
            VStack(alignment: .leading, spacing: 2) {
                if let ip = result.ipAddress {
                    Text(ip)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Theme.Colors.textPrimary)
                }

                HStack(spacing: 8) {
                    Label("\(result.size) bytes", systemImage: "doc")
                    Label("TTL \(result.ttl)", systemImage: "clock")
                }
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textTertiary)
            }

            Spacer()

            // Response time
            Text(result.timeText)
                .font(.system(.subheadline, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(timeColor(for: result.time))
        }
        .accessibilityIdentifier("pingTool_result_\(result.sequence)")
    }

    private func timeColor(for time: Double) -> Color {
        switch time {
        case ..<20: return Theme.Colors.success
        case 20..<100: return Theme.Colors.warning
        default: return Theme.Colors.error
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PingToolView()
    }
}
