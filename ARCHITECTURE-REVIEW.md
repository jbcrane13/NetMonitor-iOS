# NetMonitor-iOS — Network Services Architecture Review

**Date:** 2026-02-13  
**Scope:** All networking services, their threading models, resource usage, and interactions  
**Purpose:** Diagnose root causes of heat/battery drain, UI lag, ping failures, unreliable port scans, and incomplete device discovery

---

## 1. Current State

### Service Inventory

| Service | Isolation | NWConnections (worst-case) | Concurrency Limit | Timeout Strategy | Cleanup |
|---|---|---|---|---|---|
| **DeviceDiscoveryService** | `@MainActor` | **~3,302** (see breakdown) | 24 hosts × 3 ports + 8 Bonjour resolves + 10 DNS | Per-probe timeouts (700ms/1200ms) | `defer { connection.cancel() }` per probe |
| **PingService** | `actor` | 3 per ping (ports 443, 80, 22) | None (sequential pings, concurrent ports) | 5s default per attempt | `defer` cancels all 3 |
| **PortScannerService** | `actor` | 20 concurrent | `maxConcurrent = 20` | 2s per port (1.5s from DeviceDetail) | `defer { connection.cancel() }` |
| **BonjourDiscoveryService** | `@MainActor` | Up to 18 NWBrowsers + resolve connections | 18 service types browsed simultaneously | 2s resolve timeout; 30s browser cleanup | Browser cancel on stop; cleanup task |
| **MacConnectionService** | `@MainActor` | 1 persistent + 1 browser | Single connection | Heartbeat every 15s; reconnect after 5s | Explicit `disconnect()` |
| **DeviceNameResolver** | `nonisolated` (Sendable) | 0 (uses `getnameinfo` on GCD) | None | 3s race timeout | GCD block completes naturally |

### NWConnection Worst-Case Breakdown (Full /24 Scan)

| Phase | Calculation | Peak Simultaneous |
|---|---|---|
| TCP probes (primary) | 24 hosts × 3 ports | **72** |
| TCP probes (secondary) | 24 hosts × 3 ports (if primary fails) | **72** |
| Bonjour service resolution | 8 concurrent resolve connections | **8** |
| SSDP multicast | 1 UDP connection | **1** |
| DNS PTR resolution | 10 concurrent (via getnameinfo, not NWConnection) | **0** NWConnections |
| **Total peak NWConnections** | | **~80** |
| **Total created over scan** | 254 hosts × up to 12 ports + 100 Bonjour resolves + 1 SSDP | **~3,149** |

**Note:** Each NWConnection involves kernel-level socket allocation, TCP state machine, and GCD dispatch. Creating ~3,000+ in rapid succession on an iPhone is the primary heat source.

---

## 2. Problem Analysis

### 🔥 Problem 1: Device Gets Very Hot (CPU/Battery Drain)

**Root Cause: Massive NWConnection churn**

1. **~3,000+ NWConnections created during a single scan.** Each TCP probe creates an NWConnection, starts a TCP handshake, then cancels it. The kernel must allocate and tear down socket file descriptors, manage TCP state (SYN_SENT → RST or timeout), and process state callbacks through GCD.

2. **`probeQueue` is a concurrent DispatchQueue with `.userInitiated` QoS.** This prevents the CPU from throttling. All 72 peak-concurrent probes compete for GCD worker threads at elevated priority.

3. **No global connection budget.** DeviceDiscoveryService, BonjourDiscoveryService (18 browsers), SSDP, and DNS resolution all run independently with no shared limiter. During a scan, the system is simultaneously managing TCP probes + Bonjour browsers + SSDP + DNS lookups.

4. **Secondary probe stage doubles work for offline hosts.** If primary ports (80, 443, 22, 445) all time out after 700ms, the system tries 9 more secondary ports at 1200ms each. For offline IPs (the majority on most networks), this means ~12 connection attempts × 700-1200ms of kernel-level TCP timeout processing per host.

5. **BonjourDiscoveryService opens 18 NWBrowsers simultaneously** for all `commonServiceTypes`. Each browser generates multicast DNS traffic and callback processing.

### 🐌 Problem 2: UI Lags Badly (Hard to Type in Text Fields)

**Root Cause: `@MainActor` on DeviceDiscoveryService**

1. **DeviceDiscoveryService is `@MainActor`.** Every property mutation (`discoveredDevices`, `scanProgress`, `scanPhase`, `isScanning`) happens on the main thread. With 254 hosts being probed, `upsertDiscoveredDevice()` is called potentially hundreds of times during a scan, each time mutating an `@Observable` array that triggers SwiftUI view updates.

2. **`scanProgress` updates on every single host completion.** With 254 hosts, that's 254 main-thread mutations during TCP probing alone, each triggering SwiftUI diffing.

3. **BonjourDiscoveryService is also `@MainActor`.** Its `browseResultsChangedHandler` dispatches to `@MainActor` for every service found across 18 browsers. During active Bonjour discovery, dozens of callbacks hit the main thread.

4. **`await` hops back to MainActor between phases.** The scan pipeline (`scanNetwork`) runs on MainActor, so after each `await` (task group completion, Bonjour merge, SSDP, DNS resolution), execution returns to the main thread before proceeding. This creates main-thread contention between scan orchestration and UI rendering.

5. **NetworkMapViewModel is `@MainActor` and reads `discoveredDevices` directly** from the service. Every `@Observable` mutation in the service cascades through the view model to SwiftUI.

### 📡 Problem 3: Ping Shows Extremely Long Latency or Timeouts

**Root Cause: TCP-based "ping" + resource contention**

1. **PingService uses TCP connection probes, not ICMP.** iOS doesn't allow raw sockets for ICMP without entitlements, so the service probes ports 443, 80, and 22. This measures TCP handshake time, not network latency. A host that doesn't listen on any of those three ports will always "time out" even if it's perfectly reachable.

2. **`connection.start(queue: .global())` in PingService.** During a concurrent device scan, `.global()` GCD threads are saturated by DeviceDiscoveryService's concurrent probes. Ping connections compete for the same thread pool, adding scheduling delay to measured "latency."

3. **5-second default timeout is too long.** If the target host doesn't listen on 443/80/22, the user waits 5 seconds per ping before seeing a timeout — and this happens sequentially for each ping in the count.

4. **No prioritization.** Ping probes use the same `.global()` queue as everything else. There's no QoS elevation or dedicated queue for interactive ping operations.

### 🔌 Problem 4: Port Scan in Device Details Is Unreliable

**Root Cause: `.waiting` state handling + concurrent scan interference**

1. **`.waiting` state is immediately treated as `.filtered`.** In PortScannerService, when NWConnection enters `.waiting` (which means "path exists but connection can't proceed yet"), the connection is immediately cancelled and reported as filtered. On congested Wi-Fi or when many connections are active, `.waiting` is a transient state that could resolve to `.ready` or `.failed` if given time.

2. **`connection.start(queue: .global())` shares the GCD pool.** If a device scan is running concurrently, the 20 port scan connections compete with 72+ discovery probe connections for GCD threads.

3. **Port scan timeout is only 1.5s** (set by DeviceDetailViewModel). Combined with GCD thread starvation, some connections may not even get their state callbacks before timeout fires.

4. **`allowLocalEndpointReuse = true` is set** but `requiredInterfaceType` is not. This means port scans could attempt non-Wi-Fi paths on dual-stack devices.

### 🔍 Problem 5: Device Discovery Finds Too Few Devices (14-20 vs 25+)

**Root Causes: Multiple compounding factors**

1. **TCP-only primary discovery.** The main scan relies on TCP connection probes to ports 80, 443, 22, 445 (primary) and 7000, 8080, 8443, 62078, 5353, 9100, 1883, 554, 548 (secondary). Many consumer devices (smart speakers, IoT sensors, game consoles, smart TVs in standby) don't listen on any of these ports. They're invisible to TCP probing.

2. **`.waiting` state kills probes prematurely.** In `probePort()`, a `.waiting` state immediately cancels the connection and returns `nil`. On a busy Wi-Fi network with 72 concurrent probes, NWConnection may briefly enter `.waiting` before the Wi-Fi interface becomes available. This causes false negatives for reachable hosts.

3. **No ARP/ICMP fallback.** iOS can't do ARP table reads or ICMP pings without entitlements. The Mac companion fills this gap, but only when connected. Without the Mac companion, discovery relies entirely on TCP probes + Bonjour + SSDP.

4. **Bonjour only gets 3 extra seconds** after TCP probes complete (`try? await Task.sleep(for: .seconds(3))`). Some Bonjour services take 5-10 seconds to appear, especially on congested networks. The 3-second window may not be enough.

5. **SSDP discovery window is only 3 seconds** with 500ms receive timeout. Slow-responding UPnP devices may be missed.

6. **Subnet detection may be wrong.** `makeScanTarget` falls back to `/24` assumption. If the network uses a different subnet mask (e.g., /23 or /22), hosts outside the assumed range are never probed.

---

## 3. Resource Budget — Proposed Global Limits

### Current (Uncontrolled)

| Resource | Current Peak | Notes |
|---|---|---|
| Simultaneous NWConnections | ~80 | No global cap |
| Total NWConnections per scan | ~3,149 | No reuse |
| GCD threads consumed | 64+ (pool max) | Thread pool exhaustion |
| MainActor mutations per scan | ~500+ | Progress + device upserts + Bonjour callbacks |
| NWBrowsers active | 18 | All service types at once |

### Proposed Budget

| Resource | Proposed Limit | Rationale |
|---|---|---|
| Simultaneous NWConnections (global) | **30** | Prevents kernel socket exhaustion; leaves headroom for system |
| TCP probe concurrency (hosts) | **12** | Half current; reduces heat significantly |
| Ports per host (primary) | **4** (keep current) | Good coverage |
| Ports per host (secondary) | Skip for offline hosts | If primary all timeout, host is likely offline |
| NWBrowsers active | **6** | Prioritize highest-yield service types |
| MainActor mutations per scan | **≤50** | Batch device upserts; throttle progress |
| DNS PTR concurrency | **5** | DNS is blocking; fewer threads occupied |
| Ping dedicated queue | **1 QoS .userInteractive** | Isolated from scan traffic |

---

## 4. Ranked Recommendations

### Priority 1: Move DeviceDiscoveryService Off MainActor (Critical — Fixes UI lag)

**Problem:** Every scan mutation blocks the main thread.

**Fix:**
- Change `DeviceDiscoveryService` from `@MainActor` to a plain `actor` or `@Observable` class with internal locking
- Publish results to MainActor only in batches (e.g., every 0.5s or per-phase, not per-host)
- Keep `@Observable` properties but update them via `MainActor.run {}` in batched intervals
- Move `BonjourDiscoveryService` off MainActor similarly

**Impact:** Eliminates the primary source of UI jank. Text field typing will be responsive during scans.

### Priority 2: Implement Global Connection Semaphore (Critical — Fixes heat)

**Problem:** No system-wide limit on concurrent NWConnections.

**Fix:**
- Create a shared `ConnectionBudget` actor with an async semaphore (e.g., `maxConcurrent: 30`)
- All services acquire a permit before creating an NWConnection, release on cancel/complete
- Replace per-service `maxConcurrent` constants with budget allocation

```swift
actor ConnectionBudget {
    static let shared = ConnectionBudget(limit: 30)
    private let limit: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    func acquire() async { ... }
    func release() { ... }
}
```

**Impact:** Caps kernel resource usage, reduces CPU scheduling overhead, directly reduces heat.

### Priority 3: Eliminate Secondary Probe Stage for Unresponsive Hosts (High — Fixes heat + discovery time)

**Problem:** If all 4 primary ports timeout (700ms each), the system tries 9 more secondary ports (1200ms each). For ~230 offline hosts on a /24, this wastes enormous resources.

**Fix:**
- If all primary ports return timeout (not connection-refused), skip secondary probes for that host
- Connection-refused on primary = host is alive, try secondary for service detection
- This eliminates ~2,070 unnecessary NWConnections per scan (230 offline hosts × 9 ports)

**Impact:** Reduces total scan connections by ~65%, proportionally reducing heat and scan time.

### Priority 4: Handle `.waiting` State Properly (High — Fixes port scan reliability + discovery count)

**Problem:** `.waiting` is immediately treated as failure, causing false negatives.

**Fix:**
- In `probePort()` and `scanPort()`, don't cancel on `.waiting` — let the timeout handle it
- Remove the `.waiting` case from the stateUpdateHandler switch (or just `break`)
- The existing timeout task will still fire and cancel the connection if it never transitions

```swift
// REMOVE this case from probePort() and scanPort():
case .waiting:
    // Let timeout handle this
    break
```

**Impact:** Hosts that briefly enter `.waiting` due to Wi-Fi congestion will be discovered. Port scans will find more open ports. Could recover 3-8 missed devices.

### Priority 5: Give PingService a Dedicated Queue (Medium — Fixes ping latency)

**Problem:** Ping uses `.global()` which is shared with scan traffic.

**Fix:**
- Create a dedicated `DispatchQueue(label: "com.netmonitor.ping", qos: .userInteractive)` in PingService
- Use this queue for all NWConnection starts in `connectTest()`
- Consider adding a "fast path" single-port probe option for hosts known to respond on a specific port

**Impact:** Ping measurements become accurate even during concurrent scans.

### Priority 6: Batch MainActor UI Updates (Medium — Further improves UI responsiveness)

**Problem:** `scanProgress` updates 254 times during TCP probing.

**Fix:**
- Throttle `scanProgress` updates to every 2% change or every 0.3s, whichever comes first
- Batch `upsertDiscoveredDevice` calls: accumulate in a local array, flush to `@Observable` every 1s or at phase boundaries
- Coalesce Bonjour `browseResultsChangedHandler` callbacks

**Impact:** Reduces MainActor contention by ~90% even before Priority 1 is implemented.

### Priority 7: Reduce NWBrowser Count (Low — Reduces background resource usage)

**Problem:** 18 simultaneous NWBrowsers for all service types.

**Fix:**
- Tier service types by discovery value. Start with top 6 (http, airplay, homekit, smb, googlecast, companion-link)
- Add remaining types in a second wave after 5s if scan is still running
- Cancel resolved browsers early

**Impact:** Modest reduction in multicast DNS traffic and GCD callback volume.

### Priority 8: Extend Bonjour/SSDP Discovery Windows (Low — Improves device count)

**Problem:** 3s Bonjour wait + 3s SSDP window misses slow responders.

**Fix:**
- Start Bonjour at scan beginning (already done) but extend the post-TCP-probe wait to 5s
- Increase SSDP collection window to 5s
- Run SSDP in parallel with Bonjour merge instead of sequentially

**Impact:** Recovers 2-4 additional devices, especially UPnP devices and slow Bonjour responders.

---

## 5. Implementation Plan

### Phase 1: Quick Wins (1-2 days) — Stop the Bleeding

1. **Remove `.waiting` → cancel in `probePort()` and `scanPort()`** (Priority 4)
   - ~10 lines changed across 2 files
   - Immediately improves discovery count and port scan reliability
   
2. **Skip secondary probes for timeout-only hosts** (Priority 3)
   - Change `probeHost()` to distinguish timeout from refusal
   - Eliminates ~65% of NWConnections per scan

3. **Give PingService a dedicated queue** (Priority 5)
   - One line: replace `.global()` with dedicated queue
   - Ping accuracy improves immediately

### Phase 2: Core Architecture Fix (3-5 days) — Fix the Heat and Lag

4. **Create `ConnectionBudget` actor** (Priority 2)
   - New file: `Utilities/ConnectionBudget.swift`
   - Integrate into DeviceDiscoveryService, PortScannerService, PingService
   - Global cap of 30 concurrent NWConnections

5. **Move DeviceDiscoveryService off `@MainActor`** (Priority 1)
   - Convert to plain `actor` or non-isolated class with `@Observable` batching
   - Add batch accumulator for device upserts
   - Throttle progress updates
   - Update NetworkMapViewModel to read from batched published state

6. **Move BonjourDiscoveryService off `@MainActor`**
   - Same pattern as DeviceDiscoveryService
   - Batch callback handling

### Phase 3: Polish (2-3 days) — Optimize Discovery

7. **Batch UI updates** (Priority 6)
   - Throttle scanProgress to 2% increments
   - Coalesce device list updates

8. **Tier NWBrowser types** (Priority 7)
   - Top 6 first, remainder after 5s delay

9. **Extend discovery windows** (Priority 8)
   - Bonjour: 5s post-probe wait
   - SSDP: 5s collection, run parallel with Bonjour merge

### Expected Outcomes

| Metric | Before | After (Phase 1+2) |
|---|---|---|
| Peak NWConnections | ~80 | ~30 |
| Total NWConnections per scan | ~3,149 | ~1,100 |
| MainActor mutations per scan | ~500+ | ~30-50 |
| Device heat during scan | Severe | Warm |
| UI responsiveness during scan | Unusable | Normal |
| Devices discovered (/24 with 25+ devices) | 14-20 | 22-25+ |
| Ping accuracy during scan | Poor | Accurate |
| Port scan reliability | Intermittent | Consistent |

---

## Appendix: File-by-File Threading Summary

| File | Isolation | Queues Used | Key Concern |
|---|---|---|---|
| `DeviceDiscoveryService.swift` | `@MainActor` | `probeQueue` (.userInitiated, concurrent) | All mutations block UI |
| `PingService.swift` | `actor` | `.global()` | Shares thread pool with scans |
| `PortScannerService.swift` | `actor` | `.global()` | `.waiting` = immediate failure |
| `BonjourDiscoveryService.swift` | `@MainActor` | Custom serial queue + `.global()` | 18 browsers, callbacks on MainActor |
| `MacConnectionService.swift` | `@MainActor` | Custom serial queue | Fine — single connection, low overhead |
| `DeviceNameResolver.swift` | `nonisolated` (Sendable) | `.global(qos: .userInitiated)` | Blocking `getnameinfo` on GCD threads |
| `ConcurrencyHelpers.swift` | `actor` (ResumeState) | N/A | Correct; no issues |
| `NetworkMapViewModel.swift` | `@MainActor` | N/A | Cascades all service mutations to SwiftUI |
| `DeviceDetailViewModel.swift` | `@MainActor` | N/A | Creates new BonjourDiscoveryService per detail view |
| `PingToolViewModel.swift` | `@MainActor` | N/A | Fine — thin wrapper |
| `ServiceProtocols.swift` | Mixed | N/A | Several protocols unnecessarily `@MainActor` |
