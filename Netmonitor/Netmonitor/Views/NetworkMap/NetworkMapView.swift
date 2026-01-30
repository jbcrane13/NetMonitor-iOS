import SwiftUI

struct NetworkMapView: View {
    @State private var viewModel = NetworkMapViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TopologyView(viewModel: viewModel)
                    .frame(height: Theme.Layout.topologyHeight)

                DeviceListSection(viewModel: viewModel)
            }
            .themedBackground()
            .navigationTitle("Network Map")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    scanButton
                }
            }
            .task {
                await viewModel.startScan()
            }
        }
        .accessibilityIdentifier("screen_networkMap")
    }
    
    private var scanButton: some View {
        Button {
            Task {
                await viewModel.startScan()
            }
        } label: {
            if viewModel.isScanning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.textPrimary))
            } else {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .accessibilityIdentifier("networkMap_button_scan")
    }
}

struct TopologyView: View {
    let viewModel: NetworkMapViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) * 0.35
            
            ZStack {
                connectionLines(center: center, radius: radius)
                gatewayNode(at: center)
                deviceNodes(center: center, radius: radius)
            }
        }
        .padding()
        .accessibilityIdentifier("networkMap_topology")
    }
    
    private func connectionLines(center: CGPoint, radius: CGFloat) -> some View {
        let displayDevices = Array(viewModel.discoveredDevices.prefix(Theme.Layout.maxTopologyDevices))
        return ForEach(Array(displayDevices.enumerated()), id: \.element.id) { index, _ in
            let angle = angleForIndex(index, total: displayDevices.count)
            let position = positionForAngle(angle, center: center, radius: radius)
            ConnectionLine(from: center, to: position)
        }
    }
    
    private func gatewayNode(at center: CGPoint) -> some View {
        GatewayNode(ipAddress: viewModel.gateway?.ipAddress)
            .position(center)
    }
    
    private func deviceNodes(center: CGPoint, radius: CGFloat) -> some View {
        let displayDevices = Array(viewModel.discoveredDevices.prefix(Theme.Layout.maxTopologyDevices))
        return ForEach(Array(displayDevices.enumerated()), id: \.element.id) { index, device in
            let angle = angleForIndex(index, total: displayDevices.count)
            let position = positionForAngle(angle, center: center, radius: radius)
            DeviceNode(
                name: device.ipAddress,
                icon: "desktopcomputer",
                isSelected: viewModel.selectedDeviceIP == device.ipAddress
            )
            .position(position)
            .onTapGesture {
                viewModel.selectDevice(device.ipAddress)
            }
        }
    }
    
    private func angleForIndex(_ index: Int, total: Int) -> Double {
        Double(index) / Double(max(total, 1)) * 2.0 * .pi - .pi / 2.0
    }
    
    private func positionForAngle(_ angle: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}

struct ConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    
    @State private var phase: CGFloat = 0
    
    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(
            Theme.Colors.accent.opacity(0.3),
            style: StrokeStyle(lineWidth: 2, dash: [5, 5], dashPhase: phase)
        )
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = 10
            }
        }
    }
}

struct GatewayNode: View {
    let ipAddress: String?
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            pulseCircle
            innerCircle
            iconAndLabel
        }
        .onAppear {
            withAnimation(Theme.Animation.pulse) {
                isPulsing = true
            }
        }
        .accessibilityIdentifier("networkMap_node_gateway")
    }
    
    private var pulseCircle: some View {
        Circle()
            .fill(Theme.Colors.accent.opacity(0.2))
            .frame(width: 80, height: 80)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.5 : 0.8)
    }
    
    private var innerCircle: some View {
        Circle()
            .fill(Theme.Colors.glassBackground)
            .frame(width: 60, height: 60)
            .overlay(
                Circle()
                    .stroke(Theme.Colors.accent, lineWidth: 2)
            )
    }
    
    private var iconAndLabel: some View {
        VStack(spacing: 2) {
            Image(systemName: "wifi.router")
                .font(.system(size: 20))
                .foregroundStyle(Theme.Colors.accent)
            Text(ipAddress ?? "Gateway")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
        }
    }
}

struct DeviceNode: View {
    let name: String
    let icon: String
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            nodeCircle
            nodeLabel
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(Theme.Animation.spring, value: isSelected)
        .accessibilityIdentifier("networkMap_node_\(name.replacingOccurrences(of: ".", with: "_"))")
    }
    
    private var nodeCircle: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.glassBackground)
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Theme.Colors.accent : Theme.Colors.glassBorder, lineWidth: isSelected ? 2 : 1)
                )
            
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.textPrimary)
        }
    }
    
    private var nodeLabel: some View {
        Text(name)
            .font(.caption2)
            .foregroundStyle(Theme.Colors.textSecondary)
            .lineLimit(1)
    }
}

struct DeviceListSection: View {
    let viewModel: NetworkMapViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            deviceList
        }
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("networkMap_deviceList")
    }
    
    private var headerSection: some View {
        HStack {
            Text("Devices")
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if viewModel.isScanning {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("\(Int(viewModel.scanProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            } else {
                Text("\(viewModel.deviceCount) found")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, Theme.Layout.screenPadding)
        .padding(.vertical, 12)
    }
    
    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.discoveredDevices) { device in
                    DeviceRow(
                        device: device,
                        isSelected: viewModel.selectedDeviceIP == device.ipAddress
                    )
                    .onTapGesture {
                        viewModel.selectDevice(device.ipAddress)
                    }
                }
            }
            .padding(.horizontal, Theme.Layout.screenPadding)
            .padding(.bottom, Theme.Layout.screenPadding)
        }
    }
}

struct DeviceRow: View {
    let device: DiscoveredDevice
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: Theme.Layout.itemSpacing) {
            deviceIcon
            deviceDetails
            Spacer()
            latencyBadge
        }
        .padding(Theme.Layout.itemSpacing)
        .background(rowBackground)
        .overlay(rowBorder)
        .accessibilityIdentifier("deviceRow_\(device.ipAddress.replacingOccurrences(of: ".", with: "_"))")
    }
    
    private var deviceIcon: some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.glassBackground)
                .frame(width: 40, height: 40)
            
            Image(systemName: "desktopcomputer")
                .font(.system(size: 18))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
    
    private var deviceDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(device.ipAddress)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Theme.Colors.textPrimary)
                .fontDesign(.monospaced)
            
            Text("Discovered \(device.discoveredAt, style: .relative) ago")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
    
    private var latencyBadge: some View {
        let color = Theme.Colors.latencyColor(ms: device.latency)
        return Text(device.latencyText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: Theme.Layout.buttonCornerRadius)
            .fill(isSelected ? Theme.Colors.accent.opacity(0.1) : Theme.Colors.glassBackground)
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: Theme.Layout.buttonCornerRadius)
            .stroke(isSelected ? Theme.Colors.accent.opacity(0.5) : Color.clear, lineWidth: 1)
    }
}

#Preview {
    NetworkMapView()
}
