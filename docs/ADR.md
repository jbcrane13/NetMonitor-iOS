# Architecture Decision Records — NetMonitor iOS

A running log of significant architecture and design decisions. Both Daneel (OpenClaw) and Claude Code sessions should consult this before making structural changes, and append new entries when decisions are made.

**Format:** Date → Decision → Context → Consequences

---

## ADR-001: XcodeGen for project management
**Date:** 2026-02-09  
**Status:** Active  
**Decision:** Use XcodeGen (`project.yml`) instead of manually maintaining the `.xcodeproj`.  
**Context:** Multiple agents and Blake all modify the project; merge conflicts in `.xcodeproj` are painful.  
**Consequences:**
- Run `xcodegen generate` after any project.yml change
- Build settings like `DEVELOPMENT_TEAM`, `CODE_SIGN_ENTITLEMENTS` must be in `project.yml` or they get wiped on regeneration
- `.xcodeproj` is gitignored (regenerated)

---

## ADR-002: Swift 6 strict concurrency from day one
**Date:** 2026-02-09  
**Status:** Active  
**Decision:** `SWIFT_STRICT_CONCURRENCY: complete` and Swift 6.0 language mode.  
**Context:** Prevents data races; forces explicit isolation decisions upfront rather than retrofitting later.  
**Consequences:**
- All types crossing isolation boundaries must be `Sendable`
- UI-bound services/VMs are `@MainActor @Observable`
- Network-heavy services that need true parallelism use `actor`
- Some `nonisolated(unsafe)` and `@unchecked Sendable` workarounds exist — these should be documented (see ADR beads)

---

## ADR-003: TCP-based ping instead of ICMP
**Date:** 2026-02-10  
**Status:** Active  
**Decision:** PingService uses TCP connect probes (ports 443, 80, 22) rather than raw ICMP.  
**Context:** iOS doesn't allow raw sockets without special entitlements. TCP connect to common ports is a reliable proxy for host reachability and latency.  
**Consequences:**
- Latency reflects TCP handshake time, not ICMP RTT (slightly higher)
- Hosts that block all three ports appear unreachable
- No special entitlements needed

---

## ADR-004: NetworkScanKit as local Swift package
**Date:** 2026-02-14  
**Status:** Active  
**Decision:** Extract scan infrastructure into a local SPM package (`Netmonitor/NetworkScanKit/`).  
**Context:** Scan logic (ARP, Bonjour, TCP probe, SSDP, reverse DNS) was tangled inside `DeviceDiscoveryService` (936 lines). Needed composable scan phases for the 2.0 shared-codebase goal.  
**Consequences:**
- `ScanPhase` protocol + `ScanEngine` actor + `ScanPipeline` orchestrator
- Types like `DiscoveredDevice`, `ScanAccumulator`, `ConnectionBudget` moved to package
- App files must `import NetworkScanKit` for moved types
- Package resolves as `XCLocalSwiftPackageReference` in the xcodeproj

---

## ADR-005: ARP cache scanning for device discovery
**Date:** 2026-02-14  
**Status:** Active  
**Decision:** Use UDP probe + BSD sysctl ARP cache read as the primary device discovery mechanism.  
**Context:** Competitive analysis showed ARP scanning finds significantly more devices than TCP probing alone (34 devices vs ~15). It's the technique used by Fing, Net Analyzer, etc.  
**Consequences:**
- BSD routing types defined inline (iOS SDK doesn't export `<net/route.h>`)
- ARP phase runs first, overlapped with Bonjour
- Found devices skip TCP probing (saves NWConnections and heat)

---

## ADR-006: Tiered Bonjour browsing
**Date:** 2026-02-14  
**Status:** Active  
**Decision:** Browse high-yield Bonjour service types (HTTP, SMB, SSH, AirPlay) immediately; defer low-yield types by 3-5 seconds.  
**Context:** Browsing 18 service types simultaneously creates resource pressure during the scan's critical window. Most useful results come from ~6 types.  
**Consequences:**
- Tier 1 (6 types): immediate
- Tier 2 (12 types): delayed 3s
- 30s timeout auto-finishes discovery to prevent hung streams

---

## ADR-007: Generation-based stale callback prevention
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Use monotonically increasing generation IDs in `BonjourDiscoveryService` (and `BonjourDiscoveryToolViewModel`) to prevent stale NWBrowser callbacks from prior sessions from polluting current results.  
**Context:** Bonjour discovery tool kept breaking because callbacks from cancelled browsers arrived after a new discovery had started. `onTermination` calling `stopDiscovery()` also caused re-entrancy.  
**Consequences:**
- Every browser callback checks `self.generation == gen` before processing
- `onTermination` removed from AsyncStream — teardown is explicit only
- ViewModel uses `runID` to prevent stale tasks from resetting state

---

## ADR-008: ViewModels own services via @State, not singletons
**Date:** 2026-02-09  
**Status:** Active (with exceptions)  
**Decision:** Views create ViewModels via `@State`, ViewModels create services in `init()`. Avoid global singletons where possible.  
**Context:** Testability and lifecycle clarity. Each tool screen manages its own service lifecycle.  
**Consequences:**
- Some services (NetworkMonitorService, WiFiInfoService) are still effectively singletons because they monitor global state
- DI via protocol injection in ViewModel init (e.g., `BonjourDiscoveryToolViewModel(bonjourService:)`)
- Architecture review (2026-02-15) flagged that `DeviceDetailViewModel` needs DI added

---

## ADR-009: Beads for task tracking
**Date:** 2026-02-14  
**Status:** Active  
**Decision:** All work tracked via `beads` (`bd` CLI) — every fix/feature gets a bead, status updates required, IDs in commit messages.  
**Context:** Multiple agents working on the codebase need a shared task tracking system that lives in the repo.  
**Consequences:**
- `.beads/` directory in repo root
- `bd list`, `bd create`, `bd close` workflow
- Dependency chains between beads (blocked-by/blocks)

---

## ADR-010: Architecture review phases (2026-02-15)
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** Four-phase remediation plan from comprehensive architecture review:
- **Phase 1 (P0-P1):** Safety fixes — scanTask assignment, @MainActor on ThemeManager, BackgroundTaskService race, DNSLookupService isolation, ContentView ThemeManager @State
- **Phase 2 (P2):** DI/Protocol cleanup — extract Phase enum, add DI to DeviceDetailViewModel, route MacConnectionService through ViewModels
- **Phase 3 (P2-P3):** Consolidation — centralize UserDefaults keys, extract shared utilities, replace deprecated OSAtomicAdd64, extract pruneExpiredData
- **Phase 4 (P3-P4):** Polish — os.Logger, document unsafe markers, evaluate singletons, re-export NetworkScanKit types, make stop() async, refactor DNS

**Context:** Full services architecture review (324-line `ARCHITECTURE-REVIEW.md`) identified ~3,000 NWConnection churn as primary heat source, threading model issues, and consolidation opportunities.  
**Consequences:**
- 22 beads created with dependency chains
- Phase 1 blocks Phase 2 blocks Phase 3 blocks Phase 4
- Epic beads track phase completion

---

## ADR-011: Build number management
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** `CURRENT_PROJECT_VERSION` in `project.yml` is a baseline; actual build numbers for TestFlight are passed via CLI (`CURRENT_PROJECT_VERSION=N`). Always check ASC API for the latest build number before uploading.  
**Context:** Build numbers must be monotonically increasing on App Store Connect. Multiple agents uploading without checking led to rejected builds.  
**Consequences:**
- Query ASC API before archive: `filter[app]=6759060947&sort=-version&limit=1`
- Pass `CURRENT_PROJECT_VERSION=<next>` on the `xcodebuild archive` CLI
- iOS App ID: 6759060947, macOS App ID: 6759060882

---

## ADR-012: Export compliance and signing in project.yml
**Date:** 2026-02-15  
**Status:** Active  
**Decision:** `DEVELOPMENT_TEAM`, `ITSAppUsesNonExemptEncryption`, and `CODE_SIGN_ENTITLEMENTS` are set in `project.yml` so they survive xcodegen regeneration.  
**Context:** These kept getting wiped every time xcodegen ran, requiring manual re-entry in Xcode.  
**Consequences:**
- `DEVELOPMENT_TEAM: 32XZRDTGK3` at project level (all targets)
- `CODE_SIGN_ENTITLEMENTS: Netmonitor/Netmonitor.entitlements` on main target only (not widget)
- `ITSAppUsesNonExemptEncryption: NO` at project level
- No more "select a development team" errors after regeneration

---

*To add a new ADR: append with the next number, include date, status, decision, context, and consequences. Reference the bead ID if applicable.*
