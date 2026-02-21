# NetMonitor iOS UI Flow Coverage Expansion Plan

**Date:** 2026-02-20  
**Status:** In Progress (Execution Ongoing)  
**Owner:** AI agent session

## Motivation

Current tests are broad in count but not yet comprehensive in outcome verification quality.  
The goal is to move from "screen remains functional" assertions to deterministic, outcome-focused tests for every user interaction.

## Baseline (Measured)

### Test Inventory
- Unit tests: `638` (`@Test`) in `NetmonitorTests`
- UI test methods: `323` (`func test...`) in `NetmonitorUITests/Tests`

### Unit-Test Coverage Baseline
Collected from:
- `/tmp/netmonitor-unit-coverage.xcresult`
- Command: `xcodebuild test ... -only-testing:NetmonitorTests -enableCodeCoverage YES`

Target coverage:
- `Netmonitor.app`: `25.83%` (`5825/22554`)
- `NetmonitorWidget.appex`: `5.38%` (`28/520`)

`Netmonitor.app` by layer:
- `Views`: `10.02%` (`1425/14228`)
- `Services`: `37.92%` (`2015/5314`)
- `ViewModels`: `70.01%` (`1130/1614`)
- `Utilities`: `82.91%` (`393/474`)
- `Models`: `92.02%` (`703/764`)

Largest uncovered files (app code):
- `Netmonitor/Netmonitor/Views/DeviceDetail/DeviceDetailView.swift` (`1683` uncovered lines)
- `Netmonitor/Netmonitor/Views/Tools/ToolsView.swift` (`1472`)
- `Netmonitor/Netmonitor/Views/Settings/SettingsView.swift` (`1250`)
- `Netmonitor/Netmonitor/Views/Settings/MacPairingView.swift` (`1016`)
- `Netmonitor/Netmonitor/Views/Tools/SpeedTestToolView.swift` (`731`)
- `Netmonitor/Netmonitor/Views/NetworkMap/NetworkMapView.swift` (`697`)

### Latest Coverage Re-Measurement (2026-02-21)
Collected from:
- `/tmp/netmonitor-unit-coverage-20260221-0010.xcresult`
- Command: `xcodebuild test -scheme Netmonitor -only-testing:NetmonitorTests -enableCodeCoverage YES ...`

Targets:
- `Netmonitor.app`: `25.61%` (`5876/22940`) - passed
- `NetmonitorWidget.appex`: `5.38%` (`28/520`) - passed
- `NetmonitorTests.xctest`: `92.16%` (`7311/7933`) - passed

`Netmonitor.app` by layer (latest):
- `Views`: `9.84%` (`1430/14530`)
- `Services`: `38.11%` (`2060/5406`)
- `ViewModels`: `70.42%` (`1131/1606`)
- `Utilities`: `82.91%` (`393/474`)
- `Models`: `92.02%` (`703/764`)

Largest uncovered files (latest app run):
- `Netmonitor/Netmonitor/Views/DeviceDetail/DeviceDetailView.swift` (`1683` uncovered lines)
- `Netmonitor/Netmonitor/Views/Settings/SettingsView.swift` (`1556`)
- `Netmonitor/Netmonitor/Views/Tools/ToolsView.swift` (`1472`)
- `Netmonitor/Netmonitor/Views/Settings/MacPairingView.swift` (`1016`)
- `Netmonitor/Netmonitor/Views/Tools/SpeedTestToolView.swift` (`731`)
- `Netmonitor/Netmonitor/Views/NetworkMap/NetworkMapView.swift` (`697`)

### Accessibility/Test Reachability Snapshot
- App accessibility IDs found: `161`
- IDs directly referenced in UI test suite: `125`
- IDs not directly referenced: `36` (mostly dynamic/generated IDs or section-level IDs)

### Quality Findings
- Many UI tests use permissive OR/fallback assertions (`||`) instead of strict expected outcomes.
- Multiple page-object selectors are stale relative to current view IDs (notably Network Map / Device Detail flows).
- No dedicated UI-test launch mode or deterministic seeding strategy is present in app runtime.

## UI Interaction Flow Inventory

### App-Level
- Launch to Dashboard (`screen_dashboard`)
- Tab navigation: Dashboard, Map, Tools, Settings

### Dashboard
- Open Settings
- View connection/session/Wi-Fi/gateway/ISP/local-device cards
- Navigate to other tabs

### Network Map
- Trigger scan
- Observe scanning state
- Sort devices (IP/Name/Latency/Source)
- Open device detail from a device row
- Empty state behavior

### Device Detail
- Header/status rendering
- Network info rows
- Quick actions (Ping/Port Scan/DNS/WoL when applicable)
- Scan ports / discover services actions
- Notes edit + persistence

### Tools Home
- Quick actions:
  - Set Target sheet open/set/clear/cancel/saved target select/delete
  - Speed Test quick action navigation
  - Ping Gateway action and result text
- Tools grid navigation to all tools
- Recent activity rendering and clear action

### Tool Screens
- Ping: host input, count picker, start/stop, results, stats, clear
- Traceroute: host input, max hops picker, run/stop, hops
- Port Scanner: host input, range picker/custom ports, run/stop, results
- DNS Lookup: domain input, record type picker, run, results/errors
- Bonjour: run/stop, services list/empty
- WHOIS: domain input, run, parsed sections/errors
- Wake-on-LAN: MAC + broadcast input, send, success/error/info
- Speed Test: run/stop, gauge, results, history
- Web Browser: URL input/open, bookmarks, recent URLs, clear recent

### Settings
- Connection section (status row, connect/disconnect, optional monitoring/target rows)
- Network tool defaults (steppers/text field)
- Monitoring settings (picker/toggle)
- Notification toggles and threshold behavior
- Appearance pickers (theme/accent)
- Export menus
- Data retention + detailed results toggle
- Clear history / clear cache alerts and confirmation flows
- About links and acknowledgements navigation

### Mac Pairing
- Sheet open/cancel
- Discovery states (searching/empty/found)
- Manual toggle/host/port/connect
- Connection status area and done button behavior

## Gap Summary

1. **Assertion strictness gap**
- Existing tests often pass when any of several conditions holds, including "screen still displayed".
- This does not reliably verify business outcomes.

2. **Selector drift gap**
- Legacy identifiers in page objects reduce real interaction coverage (especially Map -> Device Detail).

3. **Determinism gap**
- Live network dependence and no explicit UI test mode increase flake and lead to soft assertions/skips.

4. **Coverage focus gap**
- View-layer interactions are under-validated compared to model/viewmodel layers.

## Plan of Record

## Execution Update (2026-02-21)

Completed in this execution slice:
- Hardened Settings toggle interaction tests for deterministic outcome checks:
  - `Background Refresh`
  - `Target Down Alerts`
  - `New Device Alerts`
  - state transition and persistence verification
- Added deterministic Credits/Acknowledgements identifiers and strict UI assertions for:
  - intro text
  - each credits card (`Swift`, `SwiftUI`, `Network.framework`, `SwiftData`)
  - card-level fields (name/license/description)
  - `Special Thanks` heading/details
- Removed `SettingsViewModel` default-value test flakiness by isolating and restoring settings keys per test.

Validated results:
- `NetmonitorTests/SettingsViewModelTests`: passed (9/9)
- Targeted settings UI tests for toggles + credits: passed (4/4)
- Full `NetmonitorTests` run with coverage: passed (638 tests, 109 suites)

## Phase 1 - Stabilize UI Selectors and Core Flows (In Progress)
Deliverables:
- Align page objects with current accessibility IDs.
- Add strict tests for Network Map row navigation and core section identifiers.
- Remove permissive fallback assertions for updated flows.

Success criteria:
- No stale `networkMap_node_*` / `networkMap_device_*` selectors in active page objects/tests.
- Device detail navigation test uses real `networkMap_row_*` rows.

## Phase 2 - Strict Outcome Tests for All Settings and Tools Interactions
Deliverables:
- For each interactive control in Settings and Tools, assert state transition/outcome, not existence.
- Ensure tests validate:
  - changed value
  - persisted value (where applicable)
  - downstream effect (cross-screen propagation) when applicable

Success criteria:
- Every `settings_*`, `quickAction_*`, `tools_card_*`, and tool run/clear control has at least one strict outcome test.

## Phase 3 - Device Detail + Tool Result Semantics
Deliverables:
- Strengthen Device Detail tests to verify:
  - expected destination screens from quick actions
  - notes persistence
  - services/ports section transitions
- Strengthen tool tests to verify result semantics (not just presence):
  - result count changes
  - clear actions reset sections
  - invalid input paths show expected errors

Success criteria:
- No `toolStillFunctional` style fallback assertions in tool suites for covered interactions.

## Phase 4 - Unit Test Expansion for Low-Coverage Services
Deliverables:
- Add/expand deterministic unit tests for low-coverage services:
  - `DeviceDiscoveryService`
  - `TracerouteService`
  - `DNSLookupService`
  - `SpeedTestService`
  - `GatewayService`
  - `BackgroundTaskService`
- Add explicit tests for error/timeouts/cancellation branches.

Success criteria:
- Service layer coverage materially improved from baseline (`37.92%`).
- Critical timeout/cancellation/error paths executed in tests.

## Phase 5 - Coverage Guardrails and Traceability
Deliverables:
- Maintain a machine-readable interaction-to-test mapping for all accessibility IDs.
- Add quality gate checks:
  - stale selector detection
  - excessive fallback assertion linting

Success criteria:
- Each user interaction has a traceable UI test.
- Coverage deltas are visible in CI and regressions are caught early.

## Beads Execution Model

Create one parent task and scoped subtasks:
- Parent: comprehensive interaction coverage initiative
- Subtasks:
  - selector/page-object alignment
  - settings/tools strict outcomes
  - device detail strict outcomes
  - service/unit branch coverage expansion
  - guardrails/reporting

All discovered work should be linked via `discovered-from:<parent-id>`.

## Definition of Done

- Every interactive element in `Netmonitor/Netmonitor/Views/**` has at least one UI test that verifies the expected outcome.
- Tests prefer deterministic assertions over permissive OR fallbacks.
- Updated page objects match current accessibility identifiers.
- Coverage baseline is re-measured and improved after changes.
- Beads are up to date for completed and remaining tasks.
