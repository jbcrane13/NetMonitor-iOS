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
        }
        .accessibilityIdentifier("screen_tools")
    }
}

struct QuickActionsSection: View {
    let viewModel: ToolsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            
            HStack(spacing: 12) {
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
                
                QuickActionButton(
                    title: "Speed Test",
                    icon: "speedometer",
                    color: Theme.Colors.success,
                    isLoading: false
                ) {
                }
                
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
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: color))
                        .scaleEffect(0.8)
                        .frame(height: 24)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 24))
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
        ToolItem(name: "Ping", icon: "arrow.up.arrow.down", color: Theme.Colors.accent, description: "Test host reachability"),
        ToolItem(name: "Traceroute", icon: "point.topleft.down.to.point.bottomright.curvepath", color: Theme.Colors.info, description: "Trace network path"),
        ToolItem(name: "DNS Lookup", icon: "globe", color: Theme.Colors.success, description: "Query DNS records"),
        ToolItem(name: "Port Scanner", icon: "door.left.hand.open", color: Theme.Colors.warning, description: "Scan open ports"),
        ToolItem(name: "Bonjour", icon: "bonjour", color: Theme.Colors.accent, description: "Discover services"),
        ToolItem(name: "Speed Test", icon: "speedometer", color: Theme.Colors.success, description: "Test bandwidth"),
        ToolItem(name: "WHOIS", icon: "doc.text.magnifyingglass", color: Theme.Colors.info, description: "Domain information"),
        ToolItem(name: "Wake on LAN", icon: "power", color: Theme.Colors.error, description: "Wake devices remotely")
    ]
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Tools")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(tools) { tool in
                    ToolCard(tool: tool)
                }
            }
        }
        .accessibilityIdentifier("tools_section_grid")
    }
}

struct ToolItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let description: String
}

struct ToolCard: View {
    let tool: ToolItem
    
    var body: some View {
        Button {
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: tool.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(tool.color)
                        .frame(width: 36, height: 36)
                        .background(tool.color.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Spacer()
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
        .accessibilityIdentifier("toolCard_\(tool.name.lowercased().replacingOccurrences(of: " ", with: "_"))")
    }
}

struct RecentActivitySection: View {
    let viewModel: ToolsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            VStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 32))
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
        HStack(spacing: 12) {
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
