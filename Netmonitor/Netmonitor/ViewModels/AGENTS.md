<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# ViewModels

## Purpose
@MainActor @Observable state management classes that aggregate services and expose state to SwiftUI views.

## Key Files
| File | Description |
|------|-------------|
| `DashboardViewModel.swift` | Aggregates network status, WiFi, gateway, public IP services |
| `NetworkMapViewModel.swift` | Device discovery and network topology state |
| `ToolsViewModel.swift` | Tool selection and navigation state |
| `PingToolViewModel.swift` | Ping tool execution and result streaming |
| `PortScannerToolViewModel.swift` | Port scan configuration and results |
| `DNSLookupToolViewModel.swift` | DNS query execution and record display |
| `TracerouteToolViewModel.swift` | Traceroute execution and hop display |
| `BonjourDiscoveryToolViewModel.swift` | Bonjour service discovery state |
| `WHOISToolViewModel.swift` | WHOIS lookup state |
| `WakeOnLANToolViewModel.swift` | Wake-on-LAN packet sending state |

## For AI Agents

### Working In This Directory
- All ViewModels are `@MainActor @Observable` (not `ObservableObject`)
- Views own ViewModels via `@State private var viewModel = SomeViewModel()`
- Use `@Bindable` in views to create bindings to ViewModel properties
- ViewModels coordinate between multiple services
- Keep UI logic in ViewModels, not in Views

### Pattern
```swift
@MainActor @Observable
final class SomeToolViewModel {
    var results: [Result] = []
    var isRunning = false
    private let service = SomeService()

    func run() async { ... }
}
```

<!-- MANUAL: -->
