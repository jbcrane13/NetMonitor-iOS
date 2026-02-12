# ⚠️ RELEASE MANDATE — READ THIS FIRST

**Today (2026-02-12) is the LAST day of testing and fixing for the 1.0 release.**

## Rules for this session:

1. **NOTHING is out of scope.** Every bug you find must be fixed today. Do not defer anything.
2. **Two P0 blockers MUST be resolved before anything else:**
   - **Device detail screen STILL HANGS** — previous fixes (9737a18, 0cdde5e) did not resolve it. The root cause has not been found. Dig deeper.
   - **Accent color picker is STILL BROKEN** — the fix in 01d1e80 did not work. Theme.Colors.accent is still not reading from UserDefaults dynamically.
3. **Test your fixes for real.** Build the app, launch it in the simulator, navigate to the screen, and verify it works. Do not just check that the code compiles.
4. **Do not mark issues as "out of scope" or "pre-existing."** If it's broken, fix it.
5. **Create beads for every issue found.** Close them only after verified fixed.

## Known broken:
- Device detail: navigating to any device freezes the UI. The async work in DeviceDetailViewModel is blocking the main thread somehow despite structured concurrency changes.
  **ROOT CAUSE FOUND (from Xcode debugger on Blake's phone):**
  - Thread 33 stopped in `dispatch_assert_queue_fail` → `swift_task_checkIsolated` → `closure #3 in closure #1 in DNSLookupService.performDNSSecServiceLookup`
  - `DNSLookupService` is marked `@MainActor` (line 4), but `performDNSServiceLookup()` creates a `DispatchSource.makeReadSource` whose event handler fires on a background GCD queue. That handler calls `DNSServiceProcessResult`, triggering the C callback, which does `Task { await resumeState.tryResume() }` — attempting to hop to @MainActor from a non-main queue, causing a dispatch assertion failure.
  - **FIX:** Remove `@MainActor` from `DNSLookupService`. It does background DNS work and should NOT be main-actor-isolated. Only the `@Observable` properties (`lastResult`, `isLoading`, `lastError`) need main-actor updates — use `@MainActor` on those specific properties or update them via `await MainActor.run { }`. The DNS query/callback/DispatchSource work must stay off the main actor.
- Accent color: changing the picker in Settings does nothing. The cyan color stays hardcoded throughout the app.
  **ROOT CAUSE ANALYSIS:** `Theme.Colors.accent` is a static computed property that reads `UserDefaults.standard.string(forKey: "selectedAccentColor")`. It reads the correct value, BUT SwiftUI views never re-render because there's no reactive binding. Static properties don't trigger SwiftUI view updates. FIX: Either (a) create an `@Observable ThemeManager` class that views observe, with the accent color as a published property that reads/writes @AppStorage, or (b) pass `@AppStorage("selectedAccentColor")` into views and resolve the color there. Option (a) is cleaner — single source of truth.

## Priority order:
1. ~~Device detail hang~~ ✅ FIXED (a8a768b)
2. ~~DNSLookupService @MainActor fix~~ ✅ FIXED (a8a768b)
3. ~~Accent color picker~~ ✅ FIXED (a8a768b)
4. **Network Map device list theming broken** (NetMonitor-iOS-zrx) — device list display on the map page has theming issues after ThemeManager refactor. Check views in NetworkMap/ directory.
5. **Discover Services in Device Detail does nothing** (NetMonitor-iOS-a3w) — the button exists but doesn't trigger or show results. Wire up BonjourDiscoveryService properly. This is a key 1.0 feature.
6. **Bonjour discovery not working** (NetMonitor-iOS-pzx, P0) — Multiple fix attempts have failed. DO NOT just restructure timeouts again. Diagnose first: add os_log/print statements to BonjourDiscoveryService to see if NWBrowser finds anything, if the stream yields results, if filtering rejects them. Find the actual failure point. Reference macOS NetMonitor implementation at `~/Projects/NetMonitor` for a working version.
7. **Speed test too brief** (NetMonitor-iOS-tcv) — Currently runs a very short test. Should do full 5-second download + 5-second upload, showing running average throughput in real-time. User setting for 5/10/30 second duration. Reference macOS NetMonitor speed test implementation at `~/Projects/NetMonitor` for the pattern.
8. Any other issues found during QA
