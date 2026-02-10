import SwiftUI

struct DeviceListView: View {
    let discoveredDevices: [DiscoveredDevice]

    var body: some View {
        ScrollView {
            if discoveredDevices.isEmpty {
                ContentUnavailableView(
                    "No Devices Found",
                    systemImage: "network.slash",
                    description: Text("Run a network scan to discover devices")
                )
                .accessibilityIdentifier("deviceList_label_empty")
            } else {
                VStack(spacing: Theme.Layout.itemSpacing) {
                    ForEach(discoveredDevices) { device in
                        NavigationLink(destination: DeviceDetailView(ipAddress: device.ipAddress)) {
                            deviceRow(device: device)
                        }
                        .accessibilityIdentifier("deviceList_row_device_\(device.ipAddress.replacingOccurrences(of: ".", with: "_"))")
                    }
                }
                .padding(.horizontal, Theme.Layout.screenPadding)
                .padding(.vertical, Theme.Layout.smallCornerRadius)
            }
        }
        .themedBackground()
        .navigationTitle("Local Devices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .accessibilityIdentifier("deviceList_screen")
    }

    @ViewBuilder
    private func deviceRow(device: DiscoveredDevice) -> some View {
        GlassCard {
            HStack(spacing: Theme.Layout.itemSpacing) {
                Image(systemName: "desktopcomputer")
                    .foregroundStyle(Theme.Colors.accent)
                    .font(.title2)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.ipAddress)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text(device.latencyText)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        DeviceListView(discoveredDevices: [
            DiscoveredDevice(ipAddress: "192.168.1.1", latency: 5.2, discoveredAt: Date()),
            DiscoveredDevice(ipAddress: "192.168.1.100", latency: 12.8, discoveredAt: Date()),
            DiscoveredDevice(ipAddress: "192.168.1.200", latency: 8.1, discoveredAt: Date())
        ])
    }
}
