<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-02-15 -->

# Netmonitor (Source Root)

## Purpose
Application source code organized in a layered architecture: Models → Services → ViewModels → Views, with shared Utilities.

## Key Files
| File | Description |
|------|-------------|
| `NetmonitorApp.swift` | App entry point, SwiftData container, forces `.dark` color scheme |
| `ContentView.swift` | Root TabView with Dashboard, Network Map, Tools, and Settings tabs |
| `Info.plist` | Bundle configuration, permissions (location, local network), background modes |
| `Netmonitor.entitlements` | App capabilities (network extensions, Bonjour services) |
| `PrivacyInfo.xcprivacy` | Privacy manifest for App Store submission |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Models/` | SwiftData @Model classes and transient Codable types (see `Models/AGENTS.md`) |
| `Services/` | Network operation services using async/await and actors (see `Services/AGENTS.md`) |
| `ViewModels/` | @MainActor @Observable state management classes (see `ViewModels/AGENTS.md`) |
| `Views/` | SwiftUI views organized by feature (see `Views/AGENTS.md`) |
| `Utilities/` | Theme system, reusable modifiers, helpers (see `Utilities/AGENTS.md`) |
| `Assets.xcassets/` | App icons and color assets |

## For AI Agents

### Working In This Directory
- Follow the layered architecture: Views depend on ViewModels, ViewModels depend on Services, Services depend on Models
- All UI code must be `@MainActor`
- Use `@Observable` (not `ObservableObject`) for view models
- Use `@State` to own view models in views, `@Bindable` for bindings
- Swift 6 strict concurrency — no `@Sendable` violations
- Services use singleton pattern (`.shared`) for stateful services like NetworkMonitorService, MacConnectionService, DeviceDiscoveryService

### Data Flow
```
View (@State var vm) → ViewModel (@Observable) → Service (async/await) → Network.framework
                                                → SwiftData (@Query)
```

### Accessibility
All interactive elements need identifiers: `{screen}_{element}_{descriptor}`

### Codebase Stats
- 75+ Swift source files, ~44K LOC
- 20+ services, 15 ViewModels, 30+ views
- 9 unit test files (~2,626 LOC), 14 UI test files + 15 page objects
- Dark-only UI — app forces `.dark` color scheme (Liquid Glass design)

<!-- MANUAL: -->
