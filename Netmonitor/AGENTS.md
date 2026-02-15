<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-02-15 -->

# Netmonitor

## Purpose
Xcode project root. Contains the XcodeGen configuration and all application source code, assets, test suites, widget extension, and the NetworkScanKit Swift package.

## Key Files
| File | Description |
|------|-------------|
| `project.yml` | XcodeGen project definition (targets, settings, dependencies, schemes) |
| `UI-TEST-REPORT.md` | UI testing results and coverage |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Netmonitor/` | Application source code (see `Netmonitor/AGENTS.md`) |
| `NetworkScanKit/` | Swift package for composable scan phases (ARP, Bonjour, TCP probe, SSDP, reverse DNS) |
| `NetmonitorTests/` | Unit tests for services, view models, and utilities |
| `NetmonitorUITests/` | UI tests with page object pattern |
| `NetmonitorWidget/` | iOS widget extension for network status |
| `Netmonitor.xcodeproj/` | Generated Xcode project (do not edit manually) |
| `build/` | Build artifacts and derived data |
| `.omc/` | OMC state for this Xcode project |

## For AI Agents

### Working In This Directory
- Run `xcodegen generate` here after modifying `project.yml`
- Do NOT edit `Netmonitor.xcodeproj/project.pbxproj` directly — it is generated from `project.yml`
- Source code lives in the nested `Netmonitor/` subdirectory
- NetworkScanKit is a local Swift package, editable in-place

### Project Structure
```
Netmonitor/
├── project.yml              # XcodeGen config (main target + widget + tests)
├── Netmonitor/              # Main app source (Models, Services, ViewModels, Views, Utilities)
├── NetworkScanKit/          # Swift package (scan engine + 5 scan phases)
├── NetmonitorTests/         # Unit tests
├── NetmonitorUITests/       # UI tests
└── NetmonitorWidget/        # Widget extension
```

### Targets
- **Netmonitor** (iOS app) — Main application target, iOS 18.0+
- **NetmonitorWidget** — Widget extension
- **NetmonitorTests** — Unit test bundle
- **NetmonitorUITests** — UI test bundle

### Build Commands
```bash
# Generate project from project.yml
xcodegen generate

# Build app
xcodebuild build -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run unit tests
xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

<!-- MANUAL: -->
