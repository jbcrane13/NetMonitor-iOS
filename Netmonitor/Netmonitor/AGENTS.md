<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# Netmonitor (Source Root)

## Purpose
Application source code organized in a layered architecture: Models → Services → ViewModels → Views, with shared Utilities.

## Key Files
| File | Description |
|------|-------------|
| `NetmonitorApp.swift` | App entry point, SwiftData container setup, environment injection |
| `ContentView.swift` | Root TabView with Dashboard, Network Map, and Tools tabs |
| `Info.plist` | Bundle configuration, permissions, background modes |

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

### Data Flow
```
View (@State var vm) → ViewModel (@Observable) → Service (async/await) → Network.framework
                                                → SwiftData (@Query)
```

### Accessibility
All interactive elements need identifiers: `{screen}_{element}_{descriptor}`

<!-- MANUAL: -->
