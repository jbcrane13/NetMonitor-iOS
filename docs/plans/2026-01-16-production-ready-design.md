# NetMonitor iOS - Production Ready Design

**Date:** 2026-01-16
**Status:** Approved
**Goal:** Feature-complete release with solid test coverage

---

## Executive Summary

Transform NetMonitor from ~45% complete to a polished, production-ready iOS app. Work is split into two phases:

- **Phase 1:** Feature-complete standalone app (7 working tools, settings, tests)
- **Phase 2:** Ecosystem features (Mac pairing, widgets, background monitoring, speed test)

---

## Current State

| Category | Status |
|----------|--------|
| Foundation (Models, Theme, Tab Structure) | 90% complete |
| Services | 60% complete (missing Traceroute, WHOIS, SpeedTest) |
| Dashboard & Network Map | 85% complete |
| Tool Views | 0% (no UI for any tool) |
| Settings | 5% (placeholder only) |
| Testing | 0% (empty test directories) |

---

## Development Standards (Non-Negotiable)

### Modern Apple Development

All code MUST follow iOS 18+/Swift 6 patterns:

| Use | Never Use |
|-----|-----------|
| `@Observable` | `ObservableObject` |
| `@State` for owning ViewModels | `@StateObject` |
| SwiftData `@Model` | CoreData |
| `async/await` | `DispatchQueue` |
| `@MainActor` | Manual main thread dispatch |

Invoke `modern-apple-dev` skill before writing any Swift code.

### Test-Driven Development

For every feature:
1. Write failing test first
2. Run test, confirm RED
3. Write minimal code to pass
4. Run test, confirm GREEN
5. Refactor while staying green

Invoke `test-driven-development` skill before implementation.

### Superpowers Workflow

- `using-superpowers` at session start
- `writing-plans` before multi-step work
- `systematic-debugging` for any bugs
- `verification-before-completion` before marking done

---

## Phase 1: Feature-Complete Release

### Scope

| Category | Deliverables |
|----------|--------------|
| **Tools** | 7 working: Ping, Traceroute, Port Scan, DNS, Bonjour, WHOIS, Wake-on-LAN. SpeedTest shows "Coming Soon" |
| **Settings** | Refresh intervals, appearance, notifications, data management, about |
| **Testing** | ~60-70% coverage: services, ViewModels, models, 3 UI flows |
| **Polish** | Error handling, empty states, permission flows, loading states |

### Work Streams

#### Stream 1: Missing Services (~10% effort)

**TracerouteService**
- UDP-based with incrementing TTL
- AsyncStream for progressive hop results
- Hostname resolution per hop
- Configurable max hops, timeout

**WHOISService**
- TCP connection to whois servers (port 43)
- Support for domain and IP lookups
- Parse key fields: registrar, dates, nameservers
- Return both parsed and raw data

Both services follow existing patterns (actor or @MainActor @Observable).

#### Stream 2: Tool Views (~40% effort)

Eight tool UIs with consistent structure:

**PingToolView**
- Input: Host field, packet count stepper, continuous toggle
- Results: Live ping list, statistics card (min/max/avg/stddev, loss %)

**TracerouteToolView**
- Input: Host field, max hops stepper
- Results: Progressive hop list (hop#, IP, hostname, RTT)

**PortScannerToolView**
- Input: Host field, port preset picker, custom range option
- Results: Open ports list with service names, summary counts

**DNSLookupToolView**
- Input: Domain field, record type picker, optional custom DNS
- Results: Records grouped by type, query time

**BonjourDiscoveryToolView**
- Input: Service type filter, search field
- Results: Services list, detail sheet with TXT records

**WHOISToolView**
- Input: Domain/IP field
- Results: Parsed fields, raw data toggle

**WakeOnLANToolView**
- Input: Device picker or manual MAC entry
- Results: Confirmation, history list

**SpeedTestToolView (Placeholder)**
- Display: "Coming Soon" message
- Optional: "Notify Me" preference

**Shared Components:**
- `ToolInputField` - Consistent text input
- `ToolResultRow` - Reusable result row
- `ToolStatisticsCard` - Stats summary
- `ToolRunButton` - Run/Stop state button

#### Stream 3: Settings Screen (~15% effort)

**SettingsView** with sections:

**General**
- Dashboard refresh interval (30s, 1m, 5m, Manual)
- Device scan timeout (500ms - 2000ms)
- Default ping count (1-20)

**Appearance**
- App icon picker (if alternates exist)
- Haptic feedback toggle

**Notifications**
- Enable notifications toggle + permission request
- Device offline alerts toggle

**Data**
- Export network data (JSON via share sheet)
- Clear tool history (with confirmation)
- Clear discovered devices (with confirmation)

**About**
- Version and build number
- Acknowledgments/licenses
- Support contact
- Privacy policy link

**Implementation:**
- `SettingsViewModel` (@MainActor @Observable)
- `AppSettings` class wrapping UserDefaults

#### Stream 4: Error Handling & Polish (~15% effort)

**Error Presentation**
- `ToastManager` (@Observable) for transient errors
- Alert dialogs for critical errors
- Inline validation for form fields

**Empty States**
- Device list: "No devices found. Tap Scan to discover."
- Tool results: "Run {tool} to see results here."
- Recent activity: "Your recent activity will appear here."
- Bonjour: "No services discovered."

**Permission Flows**
- Location: Explain before requesting, handle denial gracefully
- Local Network: Guidance if blocked
- Notifications: Request only when enabled in Settings

**Loading States**
- Skeleton views for cards
- Progress indicators on buttons
- Disabled state during operations

**Accessibility**
- VoiceOver labels for status indicators
- Dynamic content announcements
- 44pt minimum touch targets

#### Stream 5: Testing (~20% effort)

**Unit Tests - Services**

| Service | Test Cases |
|---------|------------|
| PingService | Valid ping, timeout, DNS failure, statistics |
| PortScannerService | Open/closed detection, concurrency limits |
| DNSLookupService | Record parsing, invalid domain, custom server |
| TracerouteService | Hop progression, max hops, unreachable |
| WHOISService | Domain/IP parsing, connection failure |
| WakeOnLANService | Packet construction, MAC validation |
| DeviceDiscoveryService | Device found, subnet detection, cancellation |
| GatewayService | Detection, latency measurement |

Create `MockNWConnection` protocol for network mocking.

**Unit Tests - ViewModels**

| ViewModel | Test Cases |
|-----------|------------|
| DashboardViewModel | Refresh updates, error states |
| NetworkMapViewModel | Scan populates, selection state |
| ToolsViewModel | Execution updates activity, concurrency |

**Unit Tests - Models**
- Codable round-trips
- Enum mappings
- Computed properties

**UI Tests (3 flows)**
1. Dashboard refresh: Launch → Pull refresh → Verify update
2. Network scan: Map tab → Scan → Verify devices
3. Ping tool: Tools → Ping → Enter host → Run → Verify results

---

## Phase 2: Full Vision

### Mac Pairing

**MacConnectionService**
- Bonjour browser for `_netmon._tcp`
- TCP connection with reconnection logic
- JSON message protocol
- State tracking (disconnected, connecting, connected, error)

**Pairing Flow in Settings**
1. "Connect to Mac" shows status
2. Pairing sheet lists discovered Macs
3. Select → confirm → paired
4. Show sync status, disconnect option

**Data Sync**
- Push devices to Mac
- Pull monitoring data
- Last-write-wins conflict resolution

### Speed Test

Evaluate options:
| Approach | Consideration |
|----------|---------------|
| Cloudflare speed.cloudflare.com | Research first - free, relatively stable |
| Ookla SDK | Licensing cost but industry standard |
| Fast.com | Free but unofficial API |
| Custom servers | Full control but infrastructure cost |

### Widgets

| Size | Content |
|------|---------|
| Small | Status icon, WiFi name, signal bars |
| Medium | + Gateway latency, public IP |
| Large | + Last 3 devices, quick scan |

Requires App Group for data sharing.

### Background Monitoring

- BGTaskScheduler for periodic scans
- Local notifications for device state changes
- Respect notification preferences

---

## Implementation Order

### Phase 1 Sequence

```
1. TracerouteService + tests (TDD)
2. WHOISService + tests (TDD)
3. Shared tool components
4. PingToolView + tests (TDD)
5. TracerouteToolView + tests (TDD)
6. PortScannerToolView + tests (TDD)
7. DNSLookupToolView + tests (TDD)
8. BonjourDiscoveryToolView + tests (TDD)
9. WHOISToolView + tests (TDD)
10. WakeOnLANToolView + tests (TDD)
11. SpeedTestToolView placeholder
12. SettingsView + SettingsViewModel + tests (TDD)
13. Error handling system (ToastManager)
14. Empty states across app
15. Permission flow polish
16. Accessibility audit
17. UI tests for 3 flows
18. Final verification
```

### Phase 2 Sequence

```
1. MacConnectionService + tests
2. Mac pairing UI flow
3. Data sync protocol
4. Speed test research & decision
5. Speed test implementation (if viable)
6. Widget extension setup
7. Widget views (Small, Medium, Large)
8. Background task registration
9. Notification service
10. Final integration testing
```

---

## Success Criteria

### Phase 1 Complete When:
- [ ] All 7 tool views functional
- [ ] SpeedTest shows "Coming Soon"
- [ ] Settings fully operational
- [ ] Error handling covers all failure modes
- [ ] ~60-70% test coverage achieved
- [ ] All UI tests passing
- [ ] Accessibility audit passed
- [ ] No crashes in normal usage

### Phase 2 Complete When:
- [ ] Mac pairing works end-to-end
- [ ] Speed test functional (or documented deferral)
- [ ] All 3 widget sizes working
- [ ] Background monitoring operational
- [ ] Notifications delivered correctly

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Network.framework complexity | Follow existing service patterns, extensive testing |
| WHOIS server variability | Support multiple servers, graceful parsing failures |
| Test mocking difficulty | Create protocol-based abstractions early |
| Speed test API instability | Defer to Phase 2, research options thoroughly |

---

## Appendix: File Structure (New Files)

```
Services/
  TracerouteService.swift (new)
  WHOISService.swift (new)

Views/
  Tools/
    PingToolView.swift (new)
    TracerouteToolView.swift (new)
    PortScannerToolView.swift (new)
    DNSLookupToolView.swift (new)
    BonjourDiscoveryToolView.swift (new)
    WHOISToolView.swift (new)
    WakeOnLANToolView.swift (new)
    SpeedTestToolView.swift (new)
  Settings/
    SettingsView.swift (replace placeholder)
    SettingsViewModel.swift (new)
  Components/
    ToolInputField.swift (new)
    ToolResultRow.swift (new)
    ToolStatisticsCard.swift (new)
    ToolRunButton.swift (new)
    ToastView.swift (new)
    EmptyStateView.swift (new)

Utilities/
  AppSettings.swift (new)
  ToastManager.swift (new)

NetmonitorTests/
  Services/
    PingServiceTests.swift (new)
    PortScannerServiceTests.swift (new)
    DNSLookupServiceTests.swift (new)
    TracerouteServiceTests.swift (new)
    WHOISServiceTests.swift (new)
    WakeOnLANServiceTests.swift (new)
    DeviceDiscoveryServiceTests.swift (new)
    GatewayServiceTests.swift (new)
  ViewModels/
    DashboardViewModelTests.swift (new)
    NetworkMapViewModelTests.swift (new)
    ToolsViewModelTests.swift (new)
  Models/
    ModelCodingTests.swift (new)
  Mocks/
    MockNetworkConnection.swift (new)

NetmonitorUITests/
  DashboardUITests.swift (new)
  NetworkMapUITests.swift (new)
  PingToolUITests.swift (new)
```
