# NetmonitorTests

**Parent:** [../AGENTS.md](../AGENTS.md)
**Generated:** 2026-02-15

## Purpose

Unit tests for the NetMonitor iOS app using Swift Testing framework. Tests cover models, services, view models, and release validation.

## Key Files

| File | Purpose |
|------|---------|
| `ReleaseValidationTests.swift` | ThemeManager, DeviceDetailViewModel, NetworkMapViewModel, SettingsViewModel, NotificationService, BackgroundTaskService, SpeedTest, Bonjour, MonitoringTarget tests |
| `NetworkMonitorServiceTests.swift` | Connectivity status monitoring tests |
| `PingServiceTests.swift` | TCP-based ping service tests |
| `WakeOnLANServiceTests.swift` | Magic packet WoL tests |
| `ModelTests.swift` | SwiftData model validation tests |
| `PortScannerServiceTests.swift` | Port scanning service tests |
| `WHOISServiceTests.swift` | WHOIS lookup service tests |
| `DNSLookupServiceTests.swift` | DNS record query tests |
| `DeviceDetailTests.swift` | Device detail view model tests |
| `TracerouteServiceTests.swift` | Traceroute service tests |
| `NetworkUtilitiesTests.swift` | Utility function tests |

## For AI Agents

### Testing Patterns

1. **Framework:** Uses Swift Testing (`import Testing`, `@Test`, `@Suite`, `#expect`).
2. **MainActor Tests:** View models are `@MainActor`, so tests must be annotated `@MainActor`.
3. **SwiftData Tests:** Use in-memory `ModelConfiguration` for isolated testing:
   ```swift
   let config = ModelConfiguration(isStoredInMemoryOnly: true)
   let container = try ModelContainer(for: LocalDevice.self, configurations: config)
   ```
4. **Mock Services:** `ReleaseValidationTests.swift` includes mock implementations of service protocols.
5. **Async Tests:** Use `async` tests for service operations: `@Test func serviceName() async throws`.

### Running Tests

Run all unit tests:
```bash
xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Run a single test:
```bash
xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NetmonitorTests/ReleaseValidationTests/singletonExists
```

### Coverage

Enable code coverage:
```bash
xcodebuild test -scheme Netmonitor -enableCodeCoverage YES \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Working Instructions

- **Adding Tests:** Create `@Suite` with descriptive name, add `@Test` methods.
- **Testing Observable:** Use `@MainActor` annotation, verify published properties directly.
- **Testing Actors:** Use `await` for actor-isolated properties/methods.
- **Testing SwiftData:** Always use in-memory containers to avoid persistent storage pollution.
- **Mocking:** Create protocol-conforming mocks in test file or separate `Mocks/` directory.

### Dependencies

- Testing framework (Swift Testing)
- SwiftData (ModelContext, ModelContainer for persistence tests)
- Foundation (UserDefaults, Date, etc.)
- @testable import Netmonitor
