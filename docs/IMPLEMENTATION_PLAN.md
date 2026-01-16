# NetMonitor iOS Companion - Implementation Plan

## Overview

A phased implementation plan for building NetMonitor iOS Companion following modern Apple development practices (iOS 18+, Swift 6, SwiftUI, SwiftData, Observation framework).

**Tech Stack:**
- Swift 6 (strict concurrency)
- SwiftUI with iOS 26 Liquid Glass design
- SwiftData for persistence
- @Observable for state management
- Network.framework for networking
- WidgetKit for home screen widgets

---

## Phase 1: Project Foundation

### 1.1 Xcode Project Setup
- [ ] Create new iOS App project targeting iOS 18.0+
- [ ] Configure Swift 6 language mode with strict concurrency
- [ ] Set up project structure:
  ```
  NetMonitor/
  ├── App/
  │   ├── NetMonitorApp.swift
  │   └── ContentView.swift
  ├── Models/
  ├── Views/
  │   ├── Dashboard/
  │   ├── NetworkMap/
  │   ├── Tools/
  │   └── Settings/
  ├── ViewModels/
  ├── Services/
  ├── Utilities/
  └── Resources/
  NetMonitorWidgets/
  NetMonitorTests/
  NetMonitorUITests/
  ```
- [ ] Configure Info.plist with required usage descriptions:
  - `NSLocalNetworkUsageDescription`
  - `NSLocationWhenInUseUsageDescription`
  - `NSBonjourServices` (add `_netmon._tcp`)
- [ ] Add app icon assets
- [ ] Configure build schemes (Debug, Release)

### 1.2 Design System Foundation
- [ ] Create `Theme.swift` with color palette:
  - Background gradient (slate-900 to blue-900)
  - Accent colors (cyan, emerald, amber, red)
  - Text colors (primary, secondary)
- [ ] Create `GlassCard` view modifier for consistent glass styling
- [ ] Create `Typography.swift` with text style constants
- [ ] Create reusable components:
  - `StatusBadge` (online/offline/idle)
  - `GlassButton`
  - `MetricCard`

---

## Phase 2: Data Layer

### 2.1 SwiftData Models
- [ ] `PairedMac.swift` - Mac connection info
  ```swift
  @Model
  final class PairedMac {
      @Attribute(.unique) var id: UUID
      var name: String
      var lastConnected: Date
      var isConnected: Bool
  }
  ```
- [ ] `LocalDevice.swift` - Discovered network devices
  ```swift
  @Model
  final class LocalDevice {
      @Attribute(.unique) var id: UUID
      var ipAddress: String
      var macAddress: String
      var hostname: String?
      var vendor: String?
      var deviceType: DeviceType
      var customName: String?
      var status: DeviceStatus
      var firstSeen: Date
      var lastSeen: Date
  }
  ```
- [ ] `MonitoringTarget.swift` - Ping targets
- [ ] `ToolResult.swift` - Tool execution history
- [ ] `SpeedTestResult.swift` - Speed test history

### 2.2 Supporting Types (Enums)
- [ ] `DeviceType.swift` - Device classification with SF Symbol icons
- [ ] `DeviceStatus.swift` - active/idle/offline
- [ ] `ConnectionType.swift` - wifi/cellular/ethernet/none
- [ ] `ToolType.swift` - All available network tools
- [ ] `TargetProtocol.swift` - ICMP/TCP/HTTP

### 2.3 Transient Models (Codable, not persisted)
- [ ] `NetworkStatus.swift` - Current network state snapshot
- [ ] `WiFiInfo.swift` - WiFi connection details
- [ ] `GatewayInfo.swift` - Gateway information
- [ ] `ISPInfo.swift` - Public IP and ISP details
- [ ] `PingResult.swift` - Individual ping response
- [ ] `TracerouteHop.swift` - Single traceroute hop
- [ ] `PortScanResult.swift` - Port scan findings
- [ ] `DNSRecord.swift` - DNS lookup results
- [ ] `BonjourService.swift` - Discovered Bonjour service

### 2.4 SwiftData Container Setup
- [ ] Configure ModelContainer in `NetMonitorApp.swift`
- [ ] Set up model schema with all @Model types
- [ ] Configure autosave behavior

---

## Phase 3: Service Layer

### 3.1 Network Monitoring Service
- [ ] `NetworkMonitorService.swift` (@MainActor @Observable)
  - Use `NWPathMonitor` for connection status
  - Detect WiFi vs Cellular
  - Publish current `NetworkStatus`
  - Handle network transitions gracefully

### 3.2 WiFi Info Service
- [ ] `WiFiInfoService.swift`
  - Get SSID (requires location permission)
  - Get BSSID
  - Signal strength (if available via private API or NEHotspotHelper)
  - Channel/frequency info

### 3.3 Device Discovery Service
- [ ] `DeviceDiscoveryService.swift` (@MainActor @Observable)
  - ARP table scanning
  - Ping sweep for /24 subnet
  - MAC address vendor lookup (local database)
  - Device type inference from vendor/hostname
  - Background scanning support

### 3.4 Gateway Service
- [ ] `GatewayService.swift`
  - Detect gateway IP from routing table
  - Ping gateway for latency
  - ARP lookup for gateway MAC
  - Vendor lookup

### 3.5 Public IP Service
- [ ] `PublicIPService.swift`
  - Fetch public IP from external API (ipify, ipinfo, etc.)
  - Get ISP info, ASN, location
  - Cache results with TTL

### 3.6 Mac Communication Service
- [ ] `MacConnectionService.swift` (@MainActor @Observable)
  - Bonjour browser for `_netmon._tcp`
  - Connection state management
  - JSON message encoding/decoding
  - Reconnection logic
  - Data sync handling

### 3.7 CloudKit Sync Service (Deferred)
- [ ] `CloudSyncService.swift`
  - Sync configuration
  - Push/pull status data
  - Offline caching

---

## Phase 4: Network Tools Implementation

### 4.1 Ping Tool
- [ ] `PingService.swift`
  - ICMP ping using Network.framework
  - Configurable count, interval
  - Continuous mode support
  - Statistics calculation (min/max/avg/stddev)
  - Async stream for real-time results

### 4.2 Traceroute Tool
- [ ] `TracerouteService.swift`
  - UDP-based traceroute
  - Configurable max hops
  - Hostname resolution per hop
  - Timeout handling
  - Async stream for progressive results

### 4.3 Port Scanner Tool
- [ ] `PortScannerService.swift`
  - TCP connect scan
  - Common port presets (web, mail, database, etc.)
  - Custom range support
  - Concurrent scanning with rate limiting
  - Service name mapping

### 4.4 DNS Lookup Tool
- [ ] `DNSLookupService.swift`
  - Query multiple record types (A, AAAA, MX, TXT, CNAME, NS)
  - Custom DNS server support
  - Query timing

### 4.5 Bonjour Discovery Tool
- [ ] `BonjourDiscoveryService.swift`
  - Browse multiple service types
  - Resolve service details (host, port, TXT records)
  - Filter by service type

### 4.6 Speed Test Tool
- [ ] `SpeedTestService.swift`
  - Download speed measurement
  - Upload speed measurement
  - Latency measurement
  - Server selection
  - Progress reporting

### 4.7 WHOIS Lookup Tool
- [ ] `WHOISService.swift`
  - Domain WHOIS queries
  - IP WHOIS queries
  - Parse key fields (registrar, dates, nameservers)
  - Raw data access

### 4.8 Wake on LAN Tool
- [ ] `WakeOnLANService.swift`
  - Magic packet construction
  - UDP broadcast
  - Direct send to known IP

---

## Phase 5: Core UI - Tab Structure

### 5.1 App Entry Point
- [ ] `NetMonitorApp.swift`
  - Configure ModelContainer
  - Inject environment objects
  - Set up app appearance
- [ ] `ContentView.swift`
  - TabView with 3 tabs (Dashboard, Map, Tools)
  - Tab bar styling

### 5.2 Navigation & Routing
- [ ] `Router.swift` (@Observable)
  - Navigation paths per tab
  - Sheet presentation state
  - Deep link handling

---

## Phase 6: Dashboard Screen

### 6.1 Dashboard Container
- [ ] `DashboardView.swift`
  - ScrollView with glass cards
  - Pull-to-refresh
  - Settings gear button in toolbar
  - Connection status header

### 6.2 Dashboard Cards
- [ ] `SessionCard.swift` - Monitoring session info
- [ ] `WiFiCard.swift` - Current WiFi details
- [ ] `GatewayCard.swift` - Gateway info with latency
- [ ] `ISPCard.swift` - Public IP and ISP
- [ ] `TargetSummaryCard.swift` - Online/offline target counts
- [ ] `LocalDevicesCard.swift` - Device count with scan button

### 6.3 Dashboard ViewModel
- [ ] `DashboardViewModel.swift` (@MainActor @Observable)
  - Aggregate data from services
  - Refresh logic
  - Error handling

---

## Phase 7: Network Map Screen

### 7.1 Map View
- [ ] `NetworkMapView.swift`
  - Split layout: map (top) / list (bottom)
  - Scan controls in toolbar

### 7.2 Visual Topology
- [ ] `TopologyMapView.swift`
  - Canvas-based radial layout
  - Gateway at center
  - Device nodes arranged around gateway
  - Animated connection lines
  - Tap to select device
  - Color-coded status

### 7.3 Device List
- [ ] `DeviceListView.swift`
  - List of all discovered devices
  - Device row with icon, name, IP, status
  - Tap to show detail sheet

### 7.4 Device Detail
- [ ] `DeviceDetailSheet.swift`
  - Device icon and type
  - Editable name
  - IP/MAC/Vendor info
  - Status and timestamps
  - Action buttons (Ping, WoL, Copy)

### 7.5 Network Map ViewModel
- [ ] `NetworkMapViewModel.swift` (@MainActor @Observable)
  - Device list management
  - Scan state
  - Selection handling

---

## Phase 8: Tools Screen

### 8.1 Tools Container
- [ ] `ToolsView.swift`
  - Tools grid
  - Quick actions section
  - Recent activity section

### 8.2 Tool Cards
- [ ] `ToolCardView.swift` - Reusable tool card component
- [ ] `ToolsGridView.swift` - Grid layout of all tools

### 8.3 Quick Actions
- [ ] `QuickActionsView.swift`
  - Scan Network button
  - Speed Test button
  - Check Gateway button

### 8.4 Recent Activity
- [ ] `RecentActivityView.swift`
  - Last 5 tool results
  - Tap to view full results

---

## Phase 9: Individual Tool Views

### 9.1 Ping Tool UI
- [ ] `PingToolView.swift`
  - Host input field
  - Packet count stepper
  - Continuous toggle
  - Run/Stop button
  - Real-time results list
  - Statistics summary

### 9.2 Traceroute Tool UI
- [ ] `TracerouteToolView.swift`
  - Host input field
  - Max hops stepper
  - Run button
  - Progressive hop list
  - Visual path (optional)

### 9.3 Port Scanner UI
- [ ] `PortScannerToolView.swift`
  - Host input field
  - Port range/preset picker
  - Scan button
  - Results list with service names

### 9.4 DNS Lookup UI
- [ ] `DNSLookupToolView.swift`
  - Domain input field
  - Record type picker
  - DNS server picker
  - Query button
  - Results display

### 9.5 Bonjour Discovery UI
- [ ] `BonjourDiscoveryToolView.swift`
  - Service type filter
  - Search field
  - Services list
  - Service detail sheet

### 9.6 Speed Test UI
- [ ] `SpeedTestToolView.swift`
  - Large speedometer gauge
  - Download/Upload/Ping display
  - Start button
  - Progress animation
  - Results comparison

### 9.7 WHOIS Lookup UI
- [ ] `WHOISToolView.swift`
  - Domain/IP input field
  - Lookup button
  - Parsed results
  - Raw data toggle

### 9.8 Wake on LAN UI
- [ ] `WakeOnLANToolView.swift`
  - Device picker
  - Manual MAC entry
  - Send button
  - History list

---

## Phase 10: Settings Screen

### 10.1 Settings Container
- [ ] `SettingsView.swift`
  - List-based settings layout
  - Section grouping

### 10.2 Settings Sections
- [ ] `ConnectionSettingsSection.swift` - Mac pairing, CloudKit
- [ ] `MonitoringSettingsSection.swift` - Refresh intervals
- [ ] `NotificationSettingsSection.swift` - Alert preferences
- [ ] `AppearanceSettingsSection.swift` - Theme, icon
- [ ] `DataPrivacySection.swift` - Clear data, export
- [ ] `AboutSection.swift` - Version, support

### 10.3 Mac Pairing Flow
- [ ] `MacPairingView.swift`
  - Available Macs list
  - Pairing confirmation
  - Connection status

---

## Phase 11: Widgets

### 11.1 Widget Extension Setup
- [ ] Create Widget Extension target
- [ ] Configure App Group for data sharing
- [ ] Set up shared data container

### 11.2 Widget Views
- [ ] `SmallNetworkWidget.swift` - Status + WiFi + signal
- [ ] `MediumNetworkWidget.swift` - WiFi + gateway + targets + IP
- [ ] `LargeNetworkWidget.swift` - Full connection summary

### 11.3 Widget Timeline Provider
- [ ] `NetworkWidgetProvider.swift`
  - Timeline generation
  - Background refresh
  - Snapshot support

---

## Phase 12: Background & Notifications

### 12.1 Background Tasks
- [ ] `BackgroundTaskManager.swift`
  - Register BGTaskScheduler tasks
  - Periodic status check
  - Widget refresh triggers

### 12.2 Notification Service
- [ ] `NotificationService.swift`
  - Request permissions
  - Schedule local notifications
  - Handle notification actions
  - Configure notification categories

### 12.3 Push Notifications (Deferred)
- [ ] CloudKit push subscription setup
- [ ] Silent push handling

---

## Phase 13: Testing

### 13.1 Unit Tests
- [ ] Model tests (encoding/decoding)
- [ ] Service tests with mocked network
- [ ] ViewModel tests

### 13.2 UI Tests
- [ ] Dashboard flow tests
- [ ] Network Map interaction tests
- [ ] Tools execution tests
- [ ] Settings navigation tests

### 13.3 Performance Tests
- [ ] App launch time
- [ ] Memory usage profiling
- [ ] Network scan performance

---

## Phase 14: Polish & Optimization

### 14.1 Accessibility
- [ ] Add `.accessibilityIdentifier()` to all interactive elements
- [ ] VoiceOver labels and hints
- [ ] Dynamic Type support verification
- [ ] Reduce Motion support

### 14.2 Error Handling
- [ ] User-friendly error messages
- [ ] Retry mechanisms
- [ ] Offline mode graceful degradation
- [ ] Permission denial handling

### 14.3 Performance
- [ ] Lazy loading for lists
- [ ] Image/asset optimization
- [ ] Memory leak audit
- [ ] Battery usage optimization

### 14.4 Animation Polish
- [ ] Smooth 60fps transitions
- [ ] Loading state animations
- [ ] Haptic feedback integration

---

## Phase 15: App Store Preparation

### 15.1 Privacy & Compliance
- [ ] Privacy manifest creation
- [ ] Required reason APIs documentation
- [ ] Data collection disclosure

### 15.2 App Store Assets
- [ ] Screenshots for all device sizes
- [ ] App Preview video (optional)
- [ ] App description and keywords
- [ ] What's New text

### 15.3 Final QA
- [ ] Full regression testing
- [ ] Device compatibility testing (iPhone, iPad)
- [ ] Network condition testing (WiFi, Cellular, No network)

---

## Implementation Priority Order

### MVP (Minimum Viable Product)
1. **Phase 1** - Project Foundation
2. **Phase 2** - Data Layer (core models only)
3. **Phase 3.1-3.4** - Core Services (Network, WiFi, Discovery, Gateway)
4. **Phase 5** - Tab Structure
5. **Phase 6** - Dashboard Screen
6. **Phase 7** - Network Map Screen
7. **Phase 4.1** - Ping Tool (validates tool architecture)
8. **Phase 8** - Tools Screen (grid only)
9. **Phase 9.1** - Ping Tool UI

### Feature Complete
10. **Phase 3.5** - Public IP Service
11. **Phase 4.2-4.8** - Remaining Tools
12. **Phase 9.2-9.8** - Remaining Tool UIs
13. **Phase 10** - Settings Screen
14. **Phase 13** - Testing

### Enhanced
15. **Phase 11** - Widgets
16. **Phase 12** - Background & Notifications
17. **Phase 3.6-3.7** - Mac Communication & CloudKit

### Polish
18. **Phase 14** - Polish & Optimization
19. **Phase 15** - App Store Preparation

---

## Estimated Timeline

| Phase | Description | Estimate |
|-------|-------------|----------|
| 1 | Project Foundation | 1 day |
| 2 | Data Layer | 1 day |
| 3 | Service Layer (Core) | 2-3 days |
| 4 | Network Tools | 3-4 days |
| 5 | Tab Structure | 0.5 day |
| 6 | Dashboard | 1-2 days |
| 7 | Network Map | 2-3 days |
| 8-9 | Tools Screen + UIs | 3-4 days |
| 10 | Settings | 1 day |
| 11 | Widgets | 1-2 days |
| 12 | Background/Notifications | 1 day |
| 13 | Testing | 2-3 days |
| 14-15 | Polish & Release | 2-3 days |

**Total Estimate: 3-4 weeks** for feature-complete app

---

## Technical Decisions

### State Management
- Use `@Observable` classes for ViewModels
- Use `@State` in views to own observable references
- Use `@Bindable` for creating bindings to observable properties
- Use `@Environment` for dependency injection

### Concurrency
- All ViewModels marked `@MainActor`
- Network operations use `async/await`
- Use `Task` for async work from synchronous contexts
- Ensure all cross-actor data is `Sendable`

### Persistence
- SwiftData for local storage
- `@Query` for reactive data fetching in views
- No manual `context.save()` - rely on autosave

### Navigation
- `NavigationStack` with typed destinations
- Sheet presentation for tool interfaces and details
- Router pattern for programmatic navigation

### Networking
- Network.framework for low-level operations
- URLSession for HTTP requests (public IP, WHOIS)
- NWConnection for TCP/UDP tools
- NWPathMonitor for connectivity status
