# NetMonitor iOS v1.0 Production Plan

## Original Request
Bring NetMonitor-iOS to a shippable v1.0 release by fixing critical bugs, completing incomplete features, polishing UI, and improving service architecture.

## Interview Summary
Analysis provided via deep codebase exploration. The app has 3 tabs, 8 network tools, Liquid Glass design, SwiftUI/SwiftData stack on iOS 18+. 23 issues identified across P0-P2 severity plus unimplemented PRD features.

## Research Findings
- iOS prohibits raw ICMP sockets — TracerouteService needs TCP-based or "best effort" approach
- Swift concurrency continuation safety requires explicit single-resume guards
- SwiftUI diffing relies on stable Identifiable IDs

---

## 1. v1.0 Scope Decision

### IN v1.0
- All P0 critical bug fixes (items 1-4)
- Feature completion for Speed Test and Settings (items 5-6)
- Extended DNS record types (item 7)
- UI polish and component extraction (items 8-14)
- Service architecture cleanup (items 15-19)
- Pre-launch build validation

### DEFERRED to v2.0
- Mac Communication / Bonjour pairing / CloudKit sync (item 20)
- Widgets (item 21)
- Background monitoring with BGTaskScheduler (item 22)
- Monitoring/uptime alerts service (item 23)

**Rationale:** v1.0 ships a solid standalone iOS app. Mac companion, widgets, and background monitoring are additive features that don't block a quality v1.0 release.

---

## 2. Phase 1: Critical Bug Fixes (P0)

### Task 1.1: Fix TracerouteService — TCP-based approach
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/TracerouteService.swift`
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/ViewModels/TracerouteToolViewModel.swift` (if interface changes)
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/TracerouteToolView.swift` (if UI needs "limitations" disclosure)

**Changes:**
- Replace UDP-send/ICMP-receive approach with TCP connect probe per TTL increment
- Use `NWConnection` with incrementing hop limit via `IP_TTL` socket option on the underlying socket
- If TCP TTL approach also hits iOS sandbox limits, pivot to: (a) display honest "traceroute unavailable on iOS" message, or (b) use an external API endpoint for traceroute data
- Add a disclaimer label in the UI if results are approximated

**Acceptance Criteria:**
- Traceroute either shows real intermediate hops with plausible RTTs, OR shows a clear user-facing message explaining iOS limitations
- No hop returns destination IP with near-zero RTT (the current broken behavior)
- Builds without warnings

**Dependencies:** None

---

### Task 1.2: Fix PingService packet loss calculation
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/PingService.swift`

**Changes:**
- In `calculateStatistics`, change `transmitted` to use the requested `count` parameter (or a tracked counter of attempted pings) instead of `results.count`
- Ensure failed pings are either: (a) added to results with a failure marker, or (b) tracked via a separate `attemptedCount` property
- Packet loss formula: `(attempted - successful) / attempted * 100`

**Acceptance Criteria:**
- When 10 pings requested and 3 fail, packet loss shows 30% (not 0%)
- Statistics `transmitted` count matches requested count
- Unit-testable: the calculation logic can be verified in isolation

**Dependencies:** None

---

### Task 1.3: Fix BonjourDiscoveryService double-resume
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/BonjourDiscoveryService.swift`

**Changes:**
- In `resolveService`, wrap the continuation in a `ResumeState` guard (use the existing one from `Utilities/ConcurrencyHelpers.swift`)
- Ensure the timeout cancellation path and the delegate callback path cannot both resume the continuation
- Remove any local `ResumeState` if duplicated here; import from ConcurrencyHelpers

**Acceptance Criteria:**
- No runtime crash from double-resume under any timing scenario
- Service discovery still resolves services correctly
- Timeout path gracefully returns nil or throws, does not crash

**Dependencies:** None (but Task 4.1 will later consolidate ResumeState)

---

### Task 1.4: Fix DNSLookupService filter bug
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/DNSLookupService.swift`

**Changes:**
- Line 74 area: remove the trailing `|| type == .a` condition that causes A queries to also return AAAA records
- The filter should be: return records matching ONLY the requested record type

**Acceptance Criteria:**
- Querying for A records returns only A records
- Querying for AAAA records returns only AAAA records
- No cross-contamination between record types

**Dependencies:** None

---

## 3. Phase 2: Feature Completion (P1)

### Task 2.1: Implement SpeedTestToolView + ViewModel + Service
**Files:**
- CREATE: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/SpeedTestService.swift`
- CREATE: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/ViewModels/SpeedTestToolViewModel.swift`
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/SpeedTestToolView.swift` (replace stub)
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/ToolsView.swift` (fix quick action empty closure, item 13)

**Changes:**
- `SpeedTestService`: Download-based throughput measurement using `URLSession`.
  - **Default endpoint:** `https://speed.cloudflare.com/__down?bytes=25000000` (25MB download, public, no API key, documented at speed.cloudflare.com). Upload test via `POST` to `https://speed.cloudflare.com/__up`.
  - **Fallback endpoints:** `https://proof.ovh.net/files/10Mb.dat` (OVH), `http://ipv4.download.thinkbroadband.com/10MB.zip` (ThinkBroadband).
  - Measure throughput via `URLSessionTaskDelegate` `didWriteData`/`didReceiveData` progress callbacks, calculating bytes/second over sliding 1-second windows.
  - Latency measured via initial TCP connection time from `URLSessionTaskMetrics`.
  - Return `SpeedTestResult` (model already exists in SwiftData).
  - Endpoint list stored as a constant array; future Settings integration can make this user-configurable.
- `SpeedTestToolViewModel`: `@MainActor @Observable` class. Properties: `downloadSpeed`, `uploadSpeed`, `latency`, `isRunning`, `progress`, `results: [SpeedTestResult]`. Methods: `startTest()`, `stopTest()`.
- `SpeedTestToolView`: Show download/upload gauges, latency, progress indicator during test, history list of past results via `@Query`.
- Fix ToolsView quick action: wire speed test card tap to navigate to SpeedTestToolView.

**Acceptance Criteria:**
- Speed test runs and displays download/upload speeds in Mbps
- Results persist via SwiftData `SpeedTestResult`
- Progress shown during test
- Can cancel mid-test
- Quick action in ToolsView navigates to speed test
- Follows existing Liquid Glass design patterns

**Dependencies:** None

---

### Task 2.2: Implement Settings Screen
**Files:**
- CREATE: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Settings/SettingsView.swift`
- CREATE: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/ViewModels/SettingsViewModel.swift`
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Dashboard/DashboardView.swift` (remove inline `SettingsView` stub at ~line 353 and wire navigation to the new file)

**Changes:**
- `SettingsViewModel`: `@MainActor @Observable`. Manage user preferences via `@AppStorage` or a `UserDefaults`-backed model. Settings: ping count default, port scan timeout, DNS server preference, theme accent color, data retention period, clear history actions.
- `SettingsView`: Grouped list with sections: General, Network Tools, Data & Privacy, About. Each section with appropriate controls (toggles, pickers, steppers).
- **CRITICAL:** Remove the inline `struct SettingsView` stub (~line 353) from `DashboardView.swift` to avoid duplicate type error. Wire the settings button to navigate to the new `Views/Settings/SettingsView.swift`.

**Acceptance Criteria:**
- Settings screen accessible from Dashboard
- At least 5 meaningful settings that persist across launches
- Clear history action works (deletes SwiftData records)
- About section shows app version and build number
- Follows Liquid Glass design

**Dependencies:** None

---

### Task 2.3: Extend DNSLookupService for all record types
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/DNSLookupService.swift`
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/DNSLookupToolView.swift` (if UI needs updating for new types)
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/ViewModels/DNSLookupToolViewModel.swift` (if needed)

**Changes:**
- Implement query logic for MX, CNAME, TXT, NS, SOA, PTR record types (enum cases already exist)
- Use `dnssd` or `CFHost` APIs, or raw DNS query construction via `Network.framework`
- Parse response data into appropriate `DNSRecord` fields for each type

**Acceptance Criteria:**
- All record types in the enum are queryable
- MX records show priority + exchange
- TXT records show full text content
- CNAME shows canonical name
- NS shows nameserver
- SOA shows all SOA fields
- PTR shows reverse DNS name
- UI picker allows selecting any record type

**Dependencies:** Task 1.4 (DNS filter bug fix first)

---

## 4. Phase 3: UI Polish & Component Extraction (P2)

### Task 3.1: Extract ToolClearButton component
**Files:**
- CREATE: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Components/ToolClearButton.swift`
- MODIFY (7 files): All tool views containing the duplicated trash button pattern:
  - `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/PingToolView.swift`
  - `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/PortScannerToolView.swift`
  - `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/DNSLookupToolView.swift`
  - `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/TracerouteToolView.swift`
  - `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/WHOISToolView.swift`
  - `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/WakeOnLANToolView.swift`
  - `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/BonjourDiscoveryToolView.swift`

**Changes:**
- Create `ToolClearButton` taking a `title: String` (or default "Clear Results") and `action: () -> Void`
- Replace all 7 duplicated ~15-line trash button patterns with `ToolClearButton { viewModel.clearResults() }`

**Acceptance Criteria:**
- Single source of truth for clear button styling
- All 7 tool views use the shared component
- Visual appearance unchanged

**Dependencies:** None

---

### Task 3.2: Unify MetricRow and ToolResultRow
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Components/MetricCard.swift` (contains `MetricRow` as an inline struct)
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Components/ToolResultRow.swift`
- MODIFY: All views referencing either component (DashboardView.swift uses MetricRow, tool views use ToolResultRow)

**Changes:**
- Analyze both components, identify shared structure
- Create a unified `InfoRow` (or keep `MetricRow` with extended API) that handles both use cases
- Update all call sites

**Acceptance Criteria:**
- Single row component for label-value display
- No visual regression in any view using either component
- Code compiles cleanly

**Dependencies:** None

---

### Task 3.3: Fix ToolRunButton dead code
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Components/ToolRunButton.swift`

**Changes:**
- Reorder conditional branches so stop icon is reachable when `isRunning` is true
- The stop icon should show instead of (or alongside) ProgressView when running

**Acceptance Criteria:**
- Stop button visible and tappable during tool execution
- ProgressView still shown during running state
- Button correctly toggles between run/stop states

**Dependencies:** None

---

### Task 3.4: Replace hardcoded magic numbers with Theme constants
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Utilities/Theme.swift`
- MODIFY: Various view files containing hardcoded values (topology height 300, device prefix 8, signal bar dimensions, font size 36, various widths)

**Changes:**
- Add to `Theme.Layout`: `topologyHeight`, `signalBarWidth`, `signalBarMaxHeight`, `heroFontSize`, etc.
- Add to `Theme` a `Strings` or `Constants` section for non-layout magic numbers (device prefix length, etc.)
- Replace all hardcoded values in views with Theme references

**Acceptance Criteria:**
- All hardcoded values identified in the analysis are replaced: topology height (300), device prefix (8), signal bar dimensions (width: 4, height formula), font size (36), result column widths (30, 50, 60), padding values (8, 12), cornerRadius (12), latency thresholds
- These specific values sourced from Theme constants
- Visual appearance unchanged

**Dependencies:** None

---

### Task 3.5: Fix latency badge coloring
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Dashboard/DashboardView.swift` (GatewayCard is an inline struct at ~line 203)
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/NetworkMap/NetworkMapView.swift` (DeviceRow is an inline struct)

**Changes:**
- Add conditional color logic based on latency value thresholds:
  - Green: < 50ms
  - Yellow: 50-150ms
  - Red: > 150ms
- Match the pattern already used in `PingResultRow`

**Acceptance Criteria:**
- Latency badges show green/yellow/red based on value
- Thresholds consistent across all latency displays
- Color logic extracted to a shared helper or Theme extension

**Dependencies:** None

---

### Task 3.6: Fix unstable UUIDs in ToolStatistic and ToolItem
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Components/ToolStatisticsCard.swift` (contains `ToolStatistic` as an inline struct)
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Views/Tools/ToolsView.swift` (contains `ToolItem` as an inline struct)

**Changes:**
- Replace `let id = UUID()` with stable identifiers derived from content (e.g., title string, or a static ID)
- For `ToolStatistic`: use the label/title as id, or make it a struct with computed id
- For `ToolItem`: use the tool name/type as a stable identifier

**Acceptance Criteria:**
- No `UUID()` calls in `Identifiable` conformances for view-data types
- SwiftUI lists don't re-render unnecessarily
- No visual change

**Dependencies:** None

---

## 5. Phase 4: Service Architecture (P2)

### Task 4.1: Consolidate ResumeState implementations
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Utilities/ConcurrencyHelpers.swift`
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/WakeOnLANService.swift`
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/WHOISService.swift`

**Changes:**
- Keep the `ResumeState` in `ConcurrencyHelpers.swift` as the single source of truth
- Remove duplicate `ResumeState` from WakeOnLAN and WHOIS services
- Import from ConcurrencyHelpers in both services

**Acceptance Criteria:**
- Single `ResumeState` definition in ConcurrencyHelpers
- Both services compile and function correctly using shared type
- No duplicate type definitions

**Dependencies:** Task 1.3 (Bonjour fix uses ResumeState)

---

### Task 4.2: Standardize error handling across services
**Files:**
- MODIFY: All 11 service files in `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/`

**Changes:**
- Define a shared `NetworkError` enum in a new or existing file (e.g., `Models/NetworkError.swift` or in `ConcurrencyHelpers.swift`)
- Cases: `.timeout`, `.connectionFailed`, `.noNetwork`, `.invalidHost`, `.permissionDenied`, `.unknown(Error)`
- Migrate all services to throw `NetworkError` instead of mixed patterns
- ViewModels catch and display user-friendly messages via a shared `errorMessage(for:)` helper

**Acceptance Criteria:**
- All services use `NetworkError` for error reporting
- No more `lastError: String?` patterns (or consistently backed by NetworkError)
- User-facing error messages are clear and actionable

**Dependencies:** All Phase 1 bug fixes complete

---

### Task 4.3: Add service injection to tool-specific ViewModels
**Files:**
- MODIFY: All tool ViewModels in `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/ViewModels/`:
  - `PingToolViewModel.swift`
  - `PortScannerToolViewModel.swift`
  - `DNSLookupToolViewModel.swift`
  - `TracerouteToolViewModel.swift`
  - `WHOISToolViewModel.swift`
  - `WakeOnLANToolViewModel.swift`
  - `BonjourDiscoveryToolViewModel.swift`
  - `SpeedTestToolViewModel.swift` (new from Task 2.1)

**Changes:**
- Add protocol-based service injection via init parameter with default
- Example: `init(pingService: PingServiceProtocol = PingService())`
- Define lightweight protocols for each service's public API
- This enables unit testing with mock services

**Acceptance Criteria:**
- All tool VMs accept service via init
- Default parameter preserves existing call sites (no view changes needed)
- At least one example unit test demonstrating mock injection

**Dependencies:** Task 2.1 (SpeedTest VM exists)

---

### Task 4.4: Fix PortRange/PortScanPreset duplication
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/ViewModels/PortScannerToolViewModel.swift`
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Models/Enums.swift` (or wherever PortScanPreset lives)

**Changes:**
- Remove `PortRange` from ViewModel
- Use `PortScanPreset` as the single source of truth
- Ensure preset provides `.range` property returning `ClosedRange<Int>`

**Acceptance Criteria:**
- Single type for port ranges
- ViewModel uses `PortScanPreset` directly
- Port scan functionality unchanged

**Dependencies:** None

---

### Task 4.5: Fix BonjourDiscoveryToolVM polling
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/Services/BonjourDiscoveryService.swift`
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/ViewModels/BonjourDiscoveryToolViewModel.swift`

**Changes:**
- Make `BonjourDiscoveryService` an `@Observable` class (or use `AsyncStream` to publish discovered services)
- Remove 500ms polling timer from ViewModel
- ViewModel observes service reactively

**Acceptance Criteria:**
- No polling timer in ViewModel
- Service updates propagate reactively to UI
- Discovery still works correctly

**Dependencies:** Task 1.3 (Bonjour double-resume fix)

---

## 6. Phase 5: Pre-Launch

### Task 5.1: Full build validation
**Files:** None created/modified (verification only)

**Changes:**
- Run `xcodebuild build -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Zero errors, zero warnings
- Run `xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- All tests pass

**Acceptance Criteria:**
- Clean build with zero warnings
- All unit tests pass
- App launches in simulator without crashes

**Dependencies:** All previous phases complete

---

### Task 5.2: Accessibility audit
**Files:**
- MODIFY: Any view files missing accessibility identifiers per convention `{screen}_{element}_{descriptor}`

**Changes:**
- Audit all interactive elements for accessibility identifiers
- Add missing identifiers following the project convention
- Verify VoiceOver labels on key screens

**Acceptance Criteria:**
- All interactive elements have accessibility identifiers
- Naming follows `{screen}_{element}_{descriptor}` convention

**Dependencies:** All UI work complete (Phases 2-3)

---

### Task 5.3: XcodeGen project validation
**Files:**
- MODIFY: `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/project.yml` (add any new files)

**Changes:**
- Ensure all newly created files are included in XcodeGen project spec
- Run `xcodegen generate` and verify project builds

**Acceptance Criteria:**
- `xcodegen generate` succeeds
- Generated project includes all new files
- Build succeeds from fresh generation

**Dependencies:** All file creation complete

---

## 7. Acceptance Criteria Summary

| Phase | Gate |
|-------|------|
| Phase 1 | All 4 P0 bugs fixed, verified by build + manual test description |
| Phase 2 | Speed test functional, Settings screen with 5+ settings, DNS supports all record types |
| Phase 3 | Zero duplicated UI patterns, zero magic numbers in views, latency colors correct, stable IDs |
| Phase 4 | Single ResumeState, unified NetworkError, all VMs injectable, no polling hacks |
| Phase 5 | Clean build, zero warnings, all tests pass, accessibility complete |

**Overall v1.0 Gate:** App builds cleanly, all tools function correctly, no known P0/P1 bugs, consistent design system usage.

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| TracerouteService TCP TTL approach blocked by iOS sandbox | HIGH | MEDIUM | Fallback: show "not available on iOS" with explanation. Do not ship broken fake data. |
| SpeedTestService needs reliable server endpoint | MEDIUM | HIGH | Use Cloudflare or similar public CDN. Make endpoint configurable in Settings. |
| DNS extended types may have platform API limitations | LOW | MEDIUM | Use `dnssd` framework which supports all standard types. Fall back to raw UDP if needed. |
| Service protocol extraction (Task 4.3) touches many files | LOW | LOW | Protocols are additive; default parameters mean zero breaking changes to views. |
| ResumeState consolidation may surface hidden timing bugs | MEDIUM | MEDIUM | Test each service individually after consolidation. |

---

## 9. File Manifest

### Files to CREATE (6)
| File | Task |
|------|------|
| `Services/SpeedTestService.swift` | 2.1 |
| `ViewModels/SpeedTestToolViewModel.swift` | 2.1 |
| `Views/Settings/SettingsView.swift` | 2.2 |
| `ViewModels/SettingsViewModel.swift` | 2.2 |
| `Views/Components/ToolClearButton.swift` | 3.1 |
| `Models/NetworkError.swift` | 4.2 |

All paths relative to `/Users/blake/Projects/NetMonitor-iOS/Netmonitor/Netmonitor/`

### Files to MODIFY (30+)
| File | Tasks |
|------|-------|
| `Services/TracerouteService.swift` | 1.1 |
| `Services/PingService.swift` | 1.2 |
| `Services/BonjourDiscoveryService.swift` | 1.3, 4.5 |
| `Services/DNSLookupService.swift` | 1.4, 2.3 |
| `Services/WakeOnLANService.swift` | 4.1 |
| `Services/WHOISService.swift` | 4.1 |
| `Services/NetworkMonitorService.swift` | 4.2 |
| `Services/WiFiInfoService.swift` | 4.2 |
| `Services/DeviceDiscoveryService.swift` | 4.2 |
| `Services/GatewayService.swift` | 4.2 |
| `Services/PublicIPService.swift` | 4.2 |
| `Services/PortScannerService.swift` | 4.2 |
| `Views/Tools/SpeedTestToolView.swift` | 2.1 |
| `Views/Tools/ToolsView.swift` | 2.1, 3.6 |
| `Views/Tools/PingToolView.swift` | 3.1 |
| `Views/Tools/PortScannerToolView.swift` | 3.1 |
| `Views/Tools/DNSLookupToolView.swift` | 3.1 |
| `Views/Tools/TracerouteToolView.swift` | 1.1, 3.1 |
| `Views/Tools/WHOISToolView.swift` | 3.1 |
| `Views/Tools/WakeOnLANToolView.swift` | 3.1 |
| `Views/Tools/BonjourDiscoveryToolView.swift` | 3.1 |
| `Views/Components/MetricCard.swift` | 3.2 (contains MetricRow inline) |
| `Views/Components/ToolResultRow.swift` | 3.2 |
| `Views/Components/ToolRunButton.swift` | 3.3 |
| `Views/Components/ToolStatisticsCard.swift` | 3.6 (contains ToolStatistic inline) |
| `Views/Dashboard/DashboardView.swift` | 2.2 (remove SettingsView stub), 3.5 (GatewayCard inline) |
| `Views/NetworkMap/NetworkMapView.swift` | 3.5 (DeviceRow inline) |
| `Utilities/Theme.swift` | 3.4 |
| `Utilities/ConcurrencyHelpers.swift` | 4.1 |
| `ViewModels/PingToolViewModel.swift` | 4.3 |
| `ViewModels/PortScannerToolViewModel.swift` | 4.3, 4.4 |
| `ViewModels/DNSLookupToolViewModel.swift` | 2.3, 4.3 |
| `ViewModels/TracerouteToolViewModel.swift` | 1.1, 4.3 |
| `ViewModels/WHOISToolViewModel.swift` | 4.3 |
| `ViewModels/WakeOnLANToolViewModel.swift` | 4.3 |
| `ViewModels/BonjourDiscoveryToolViewModel.swift` | 4.3, 4.5 |
| `Models/Enums.swift` | 4.4 |
| `Netmonitor/project.yml` | 5.3 |

---

## 10. Task Dependency Graph

```
Phase 1 (all parallel, no dependencies):
  Task 1.1 (TracerouteService)
  Task 1.2 (PingService)
  Task 1.3 (BonjourService)
  Task 1.4 (DNSLookupService)

Phase 2 (can start after Phase 1; 2.1 and 2.2 are independent of each other):
  Task 2.1 (SpeedTest) ── no Phase 1 dependency, can start immediately
  Task 2.2 (Settings) ── no Phase 1 dependency, can start immediately
  Task 2.3 (DNS extended) ── depends on 1.4

Phase 3 (mostly parallel with Phase 2 — only 3.1 must wait for 2.1 due to shared ToolsView.swift):
  Task 3.1 (ToolClearButton) ── depends on 2.1 (both touch ToolsView.swift)
  Task 3.2 (Unify MetricRow/ToolResultRow) ── independent
  Task 3.3 (ToolRunButton fix) ── independent
  Task 3.4 (Magic numbers) ── independent
  Task 3.5 (Latency coloring) ── independent
  Task 3.6 (Stable UUIDs) ── independent

Phase 4 (after Phases 1-3):
  Task 4.1 (ResumeState consolidation) ── depends on 1.3
  Task 4.2 (Error handling) ── depends on Phase 1
  Task 4.3 (Service injection) ── depends on 2.1
  Task 4.4 (PortRange dedup) ── independent
  Task 4.5 (Bonjour polling) ── depends on 1.3

Phase 5 (sequential, after all above):
  Task 5.3 (XcodeGen) → Task 5.1 (Build validation) → Task 5.2 (Accessibility audit)
```

---

## Commit Strategy

| Commit | Scope |
|--------|-------|
| `fix: resolve traceroute, ping, bonjour, and DNS critical bugs` | Phase 1 (all 4 tasks) |
| `feat: implement speed test service and UI` | Task 2.1 |
| `feat: add settings screen with user preferences` | Task 2.2 |
| `feat: support all DNS record types` | Task 2.3 |
| `refactor: extract shared UI components and fix polish issues` | Phase 3 (all 6 tasks) |
| `refactor: consolidate service architecture and error handling` | Phase 4 (all 5 tasks) |
| `chore: pre-launch validation and accessibility audit` | Phase 5 |

---

## Success Criteria

v1.0 is shippable when:
1. All 8 network tools function correctly with no known P0/P1 bugs
2. Speed test measures and persists download/upload speeds
3. Settings screen provides meaningful user configuration
4. Zero code duplication in UI components
5. Consistent error handling across all services
6. Clean build with zero warnings
7. All unit tests pass
8. Accessibility identifiers on all interactive elements
