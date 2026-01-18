import SwiftUI

/// Speed Test tool view (placeholder for future implementation)
struct SpeedTestToolView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Layout.sectionSpacing) {
                placeholderContent
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.bottom, Theme.Layout.sectionSpacing)
        }
        .themedBackground()
        .navigationTitle("Speed Test")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .accessibilityIdentifier("screen_speedTestTool")
    }

    private var placeholderContent: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            // Icon
            Image(systemName: "speedometer")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(Theme.Colors.accent.opacity(0.5))

            // Title
            Text("Coming Soon")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Theme.Colors.textPrimary)

            // Description
            Text("Internet speed testing will be available in a future update. This feature will measure download speed, upload speed, and latency to help you understand your network performance.")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Feature preview
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Planned Features")
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    FeatureRow(icon: "arrow.down.circle", text: "Download speed measurement")
                    FeatureRow(icon: "arrow.up.circle", text: "Upload speed measurement")
                    FeatureRow(icon: "clock", text: "Latency/ping testing")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Historical results tracking")
                    FeatureRow(icon: "server.rack", text: "Multiple server locations")
                }
            }

            Spacer()
        }
        .accessibilityIdentifier("speedTest_placeholder")
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SpeedTestToolView()
    }
}
