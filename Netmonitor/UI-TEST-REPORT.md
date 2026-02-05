# UI Test Report

Date: 2026-02-05
Scope: NetmonitorUITests (Dashboard, Tools, Map, Settings)

## Summary
- Added missing Settings UI coverage for data retention, detailed results, export menus, build/iOS version rows, support link, and rate app button.
- UI test run failed before executing tests due to CoreSimulatorService connection failure in the environment.

## Added/Updated Tests
- `NetmonitorUITests/Tests/SettingsUITests.swift`
  - Data retention picker exists
  - Show detailed results toggle exists
  - Export menus exist (tool results, speed tests, devices)
  - Build number row exists
  - iOS version row exists
  - Support link exists
  - Rate app button exists

## Test Execution
Command:
```
xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:NetmonitorUITests
```

Result:
- Failed to start tests. CoreSimulatorService connection became invalid; simulator services unavailable.
- Error excerpts observed:
  - "CoreSimulatorService connection became invalid. Simulator services will no longer be available."
  - "Unable to discover any Simulator runtimes"
  - "simdiskimaged crashed or is not responding"

## Follow-Up
- Resolve CoreSimulatorService availability on this machine and re-run the UI test suite.
