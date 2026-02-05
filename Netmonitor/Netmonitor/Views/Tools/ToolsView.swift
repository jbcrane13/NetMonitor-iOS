import SwiftUI

struct ToolsView: View {
    @State private var viewModel = ToolsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Layout.sectionSpacing) {
                    QuickActionsSection(viewModel: viewModel)

                    ToolsGridSection()

                    RecentActivitySection(viewModel: viewModel)
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.bottom, Theme.Layout.sectionSpacing)
            }
            .themedBackground()
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationDestination(for: ToolDestination.self) { destination in
                destination.view
            }
        }
        .accessibilityIdentifier("screen_tools")
    }
}

/// Navigation destinations for network tools
enum ToolDestination: Hashable {
    case ping
    case traceroute
    case dnsLookup
    case portScanner
    case bonjour
    case speedTest
    case whois
    case wakeOnLAN
    case webBrowser

    @ViewBuilder
    var view: some View {
        switch self {
        case .ping:
            PingToolView()
        case .traceroute:
            TracerouteToolView()
        case .dnsLookup:
            DNSLookupToolView()
        case .portScanner:
            PortScannerToolView()
        case .bonjour:
            BonjourDiscoveryToolView()
        case .speedTest:
            SpeedTestToolView()
        case .whois:
            WHOISToolView()
        case .wakeOnLAN:
            WakeOnLANToolView()
        case .webBrowser:
            WebBrowserToolView()
        }
    }
}

struct QuickActionsSection: View {
    let viewModel: ToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.itemSpacing) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            HStack(spacing: Theme.Layout.itemSpacing) {
                QuickActionButton(
                    title: "Scan Network",
                    icon: "network",
                    color: Theme.Colors.accent,
                    isLoading: viewModel.isScanning
                ) {
                    Task {
                        await viewModel.runNetworkScan()
                    }
                }

                NavigationLink(value: ToolDestination.speedTest) {
                    VStack(spacing: Theme.Layout.smallCornerRadius) {
                        Image(systemName: "speedometer")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.success)

                        Text("Speed Test")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassCard(cornerRadius: 16, padding: 0)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("quickAction_speed_test")

                QuickActionButton(
                    title: "Ping Gateway",
                    icon: "arrow.up.arrow.down",
                    color: Theme.Colors.info,
                    isLoading: false
                ) {
                    Task {
                        await viewModel.pingGateway()
                    }
                }
            }
        }
        .accessibilityIdentifier("tools_section_quickActions")
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Layout.smallCornerRadius) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .scaleEffect(0.8)
                        .frame(height: 24)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: 16, padding: 0)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .accessibilityIdentifier("quickAction_\(title.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }
}

struct ToolsGridSection: View {
    private let tools: [ToolItem] = [
        ToolItem(name: "Ping", icon: "arrow.up.arrow.down", color: Theme.Colors.accent, description: "Test host reachability", destination: .ping),
        ToolItem(name: "Traceroute", icon: "point.topleft.down.to.point.bottomright.curvepath", color: Theme.Colors.info, description: "Trace network path", destination: .traceroute),
        ToolItem(name: "DNS Lookup", icon: "globe", color: Theme.Colors.success, description: "Query DNS records", destination: .dnsLookup),
        ToolItem(name: "Port Scanner", icon: "door.left.hand.open", color: Theme.Colors.warning, description: "Scan open ports", destination: .portScanner),
        ToolItem(name: "Web Browser", icon: "safari.fill", color: Theme.Colors.info, description: "Browse network sites", destination: .webBrowser),
        ToolItem(name: "Bonjour", icon: "bonjour", color: Theme.Colors.accent, description: "Discover services", destination: .bonjour),
        ToolItem(name: "Speed Test", icon: "speedometer", color: Theme.Colors.success, description: "Test bandwidth", destination: .speedTest),
        ToolItem(name: "WHOIS", icon: "doc.text.magnifyingglass", color: Theme.Colors.info, description: "Domain information", destination: .whois),
        ToolItem(name: "Wake on LAN", icon: "power", color: Theme.Colors.error, description: "Wake devices remotely", destination: .wakeOnLAN)
    ]

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Layout.itemSpacing),
        GridItem(.flexible(), spacing: Theme.Layout.itemSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.itemSpacing) {
            Text("Network Tools")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            LazyVGrid(columns: columns, spacing: Theme.Layout.itemSpacing) {
                ForEach(tools) { tool in
                    ToolCard(tool: tool)
                }
            }
        }
        .accessibilityIdentifier("tools_section_grid")
    }
}

struct ToolItem: Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let color: Color
    let description: String
    let destination: ToolDestination
}

struct ToolCard: View {
    let tool: ToolItem

    var body: some View {
        NavigationLink(value: tool.destination) {
            VStack(alignment: .leading, spacing: Theme.Layout.smallCornerRadius) {
                HStack {
                    Image(systemName: tool.icon)
                        .font(.title3)
                        .foregroundStyle(tool.color)
                        .frame(width: 36, height: 36)
                        .background(tool.color.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.smallCornerRadius))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Text(tool.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(tool.description)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tools_card_\(tool.name.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }
}

struct RecentActivitySection: View {
    let viewModel: ToolsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Layout.itemSpacing) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                if !viewModel.recentResults.isEmpty {
                    Button("Clear") {
                        viewModel.clearActivity()
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityIdentifier("tools_button_clearActivity")
                }
            }

            if viewModel.recentResults.isEmpty {
                emptyState
            } else {
                GlassCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.recentResults.enumerated()), id: \.element.id) { index, activity in
                            ActivityRow(activity: activity)

                            if index < viewModel.recentResults.count - 1 {
                                Divider()
                                    .background(Theme.Colors.glassBorder)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("tools_section_recentActivity")
    }

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: Theme.Layout.smallCornerRadius) {
                Image(systemName: "clock")
                    .font(.title)
                    .foregroundStyle(Theme.Colors.textTertiary)
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Text("Run a tool to see results here")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

struct ActivityRow: View {
    let activity: ToolActivityItem

    var body: some View {
        HStack(spacing: Theme.Layout.itemSpacing) {
            Circle()
                .fill(activity.success ? Theme.Colors.success : Theme.Colors.error)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(activity.tool)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(activity.target)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fontDesign(.monospaced)
                }

                Text(activity.result)
                    .font(.caption)
                    .foregroundStyle(activity.success ? Theme.Colors.success : Theme.Colors.error)
            }

            Spacer()

            Text(activity.timeAgoText)
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .accessibilityIdentifier("activityRow_\(activity.tool.lowercased())_\(activity.target)")
    }
}

#Preview {
    ToolsView()
}
