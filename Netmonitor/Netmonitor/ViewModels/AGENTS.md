<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-02-15 -->

# ViewModels

## Purpose
@MainActor @Observable state management classes that aggregate services and expose state to SwiftUI views.

## Key Files
| File | Description |
|------|-------------|
| `DashboardViewModel.swift` | Aggregates NetworkMonitorService.shared, WiFiInfoService, GatewayService, PublicIPService |
| `NetworkMapViewModel.swift` | Device discovery coordination via DeviceDiscoveryService.shared, SwiftData query for devices |
| `ToolsViewModel.swift` | Tool selection, navigation state, recent results from SwiftData |
| `PingToolViewModel.swift` | Ping tool execution via PingService actor, AsyncStream result handling |
| `PortScannerToolViewModel.swift` | Port scan configuration, AsyncStream result handling via PortScannerService |
| `DNSLookupToolViewModel.swift` | DNS query execution, record type selection, result display |
| `TracerouteToolViewModel.swift` | Traceroute execution via TracerouteService actor, hop-by-hop display |
| `BonjourDiscoveryToolViewModel.swift` | Bonjour service discovery state via BonjourDiscoveryService |
| `WHOISToolViewModel.swift` | WHOIS lookup state via WHOISService actor |
| `WakeOnLANToolViewModel.swift` | Wake-on-LAN packet construction and sending via WakeOnLANService |
| `SpeedTestToolViewModel.swift` | Speed test execution, download/upload progress via SpeedTestService |
| `DeviceDetailViewModel.swift` | Device detail view state, service queries, WoL integration |
| `SettingsViewModel.swift` | App settings, theme management via ThemeManager, paired Mac management |

## For AI Agents

### Working In This Directory
- All ViewModels are `@MainActor @Observable` (not `ObservableObject`)
- Views own ViewModels via `@State private var viewModel = SomeViewModel()`
- Use `@Bindable` in views to create bindings to ViewModel properties
- ViewModels coordinate between multiple services
- Keep UI logic in ViewModels, not in Views
- **Singleton services**: Access via `.shared` (NetworkMonitorService, MacConnectionService, DeviceDiscoveryService)
- **Actor services**: Await calls to PingService, PortScannerService, TracerouteService, WHOISService
- **AsyncStream handling**: Use `Task` to consume streams, update `@Observable` properties on results

### Pattern
```swift
@MainActor @Observable
final class SomeToolViewModel {
    var results: [Result] = []
    var isRunning = false
    private let service = SomeService()

    func run() async {
        isRunning = true
        defer { isRunning = false }
        for await result in service.stream() {
            results.append(result)
        }
    }
}
```

### Singleton Service Usage
```swift
@MainActor @Observable
final class DashboardViewModel {
    private let networkMonitor = NetworkMonitorService.shared

    var connectionStatus: NetworkStatus {
        networkMonitor.currentStatus
    }
}
```

<!-- MANUAL: -->
