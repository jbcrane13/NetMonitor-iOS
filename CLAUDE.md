# CLAUDE.md

**⚠️ READ RELEASE-MANDATE.md FIRST — today is the last day for 1.0 fixes. Nothing is out of scope.**

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## ⚠️ Beads Task Tracking — MANDATORY

This project uses **beads** (`bd` CLI) for issue tracking. You MUST use it for every piece of work:

```bash
# Before starting ANY fix or feature:
bd create --title "Short description" --type bug --priority 1
bd update <BEAD-ID> --status in_progress

# When done with a fix:
bd close <BEAD-ID> --reason "What was done"

# Check open issues:
bd list --status open

# Sync state after commits:
bd sync
```

**Rules:**
1. **Every bug fix or feature gets a bead.** No exceptions.
2. **Set status to `in_progress` when you start working on it.**
3. **Close with `--reason` when verified fixed.** Not when code compiles — when it actually works.
4. **Check for existing open beads before creating duplicates:** `bd list --status open`
5. **Include bead IDs in commit messages:** `git commit -m "Fix accent color reactivity (NetMonitor-iOS-xyz)"`
6. **Run `bd sync` after pushing.**

If you skip beads, your work is untracked and unverifiable. Use them.

## Key Documents

- **`docs/ADR.md`** — Architecture Decision Records. Read before making structural changes. Append when making new decisions.
- **`ARCHITECTURE-REVIEW.md`** — Full services architecture review (2026-02-15). Details threading models, NWConnection counts, heat/battery analysis.
- **`docs/IMPLEMENTATION_PLAN.md`** — Original implementation plan.
- **`docs/NetMonitor iOS Companion - Product Requirements Document.md`** — PRD.

## Build & Development Commands

```bash
# Generate Xcode project from XcodeGen (if project.yml changed)
cd Netmonitor && xcodegen generate

# Build the app
xcodebuild build -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run unit tests
xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run a single test
xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NetmonitorTests/SomeTestClass/testMethodName

# Build with coverage
xcodebuild test -scheme Netmonitor -enableCodeCoverage YES \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

NetMonitor is an iOS 18+ network monitoring companion app using Swift 6 with strict concurrency.

**Stack:** SwiftUI, SwiftData, @Observable, Network.framework

### Layer Structure

```
App/           → Entry point (NetmonitorApp.swift) + tab navigation (ContentView.swift)
Models/        → SwiftData @Model classes + transient Codable types + enums
ViewModels/    → @MainActor @Observable classes aggregating services
Services/      → Network operations (actors, @MainActor @Observable)
Views/         → SwiftUI views organized by feature (Dashboard/, NetworkMap/, Tools/)
Utilities/     → Theme system, reusable modifiers
```

### State Management Pattern

- ViewModels are `@MainActor @Observable` classes
- Views own ViewModels via `@State`
- Use `@Bindable` for creating bindings to observable properties
- SwiftData models use `@Query` for reactive fetching

### Concurrency Pattern

- All UI-bound code marked `@MainActor`
- Services use `async/await` throughout
- `AsyncStream` for streaming results (ping, port scan)
- `actor` isolation for concurrent operations (PingService)
- Task Groups for parallel work (device discovery)

### Service Layer

11 services handle network operations:
- **NetworkMonitorService** - NWPathMonitor connectivity status
- **WiFiInfoService** - SSID/BSSID (requires location permission)
- **DeviceDiscoveryService** - TCP probing with concurrent scanning
- **GatewayService** - Gateway detection and latency
- **PublicIPService** - External API for ISP info
- **PingService** (actor) - TCP-based ping with AsyncStream
- **PortScannerService** - TCP connect scanning
- **DNSLookupService** - Multiple record type queries
- **BonjourDiscoveryService** - mDNS service discovery
- **WakeOnLANService** - Magic packet UDP broadcast

### SwiftData Models

Persisted: `PairedMac`, `LocalDevice`, `MonitoringTarget`, `ToolResult`, `SpeedTestResult`

Transient: `NetworkStatus`, `WiFiInfo`, `GatewayInfo`, `ISPInfo`, `PingResult`, `TracerouteHop`, `PortScanResult`, `DNSRecord`, `BonjourService`

## Design System

Uses "Liquid Glass" aesthetic defined in `Utilities/Theme.swift`:
- `Theme.Colors.*` - Semantic colors (accent, success, error, glass variants)
- `Theme.Layout.*` - Spacing and corner radius constants
- `GlassCard` modifier - Consistent card styling
- `GlassButton` - Styled buttons with variants (primary, secondary, success, danger, ghost)

## Accessibility Identifier Convention

All interactive elements require identifiers following: `{screen}_{element}_{descriptor}`

```swift
.accessibilityIdentifier("dashboard_button_settings")
.accessibilityIdentifier("tools_card_ping")
.accessibilityIdentifier("map_cell_device_\(device.id)")
```

## Key Configuration

- **Bundle ID:** `com.blakemiller.netmonitor`
- **Deployment Target:** iOS 18.0+
- **Swift Version:** 6.0 with `SWIFT_STRICT_CONCURRENCY: complete`
- **Build System:** XcodeGen (`Netmonitor/project.yml`)

**Required Permissions (Info.plist):**
- `NSLocalNetworkUsageDescription` - Device discovery
- `NSLocationWhenInUseUsageDescription` - WiFi SSID detection
- `NSBonjourServices` - `_netmon._tcp`, `_services._dns-sd._udp`
- `UIBackgroundModes` - `fetch`, `processing`
