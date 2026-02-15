# NetmonitorUITests

**Parent:** [../AGENTS.md](../AGENTS.md)
**Generated:** 2026-02-15

## Purpose

UI tests for the NetMonitor iOS app using XCTest and the Page Object pattern. Tests cover all major screens and workflows via accessibility identifiers.

## Key Files

| File | Purpose |
|------|---------|
| `Screens/BaseScreen.swift` | Base class providing common UI testing utilities (tap, swipe, wait, keyboard) |
| `Screens/DashboardScreen.swift` | Dashboard screen page object |
| `Screens/NetworkMapScreen.swift` | Network Map screen page object |
| `Screens/ToolsScreen.swift` | Tools tab screen page object |
| `Screens/SettingsScreen.swift` | Settings screen page object |
| `Screens/DeviceDetailScreen.swift` | Device detail screen page object |
| `Screens/PingToolScreen.swift` | Ping tool screen page object |
| `Screens/TracerouteToolScreen.swift` | Traceroute tool screen page object |
| `Screens/PortScannerToolScreen.swift` | Port scanner tool screen page object |
| `Screens/DNSLookupToolScreen.swift` | DNS lookup tool screen page object |
| `Screens/WHOISToolScreen.swift` | WHOIS tool screen page object |
| `Screens/BonjourToolScreen.swift` | Bonjour discovery tool screen page object |
| `Screens/SpeedTestToolScreen.swift` | Speed test tool screen page object |
| `Screens/WakeOnLANToolScreen.swift` | Wake-on-LAN tool screen page object |
| `Screens/WebBrowserToolScreen.swift` | Web browser tool screen page object |
| `Tests/DashboardUITests.swift` | Dashboard UI test cases |
| `Tests/NetworkMapUITests.swift` | Network Map UI test cases |
| `Tests/ToolsUITests.swift` | Tools tab UI test cases |
| `Tests/SettingsUITests.swift` | Settings UI test cases |
| `Tests/DeviceDetailUITests.swift` | Device detail UI test cases |
| `Tests/PingToolUITests.swift` | Ping tool UI test cases |
| `Tests/TracerouteToolUITests.swift` | Traceroute tool UI test cases |
| `Tests/PortScannerToolUITests.swift` | Port scanner tool UI test cases |
| `Tests/DNSLookupToolUITests.swift` | DNS lookup tool UI test cases |
| `Tests/WHOISToolUITests.swift` | WHOIS tool UI test cases |
| `Tests/BonjourToolUITests.swift` | Bonjour tool UI test cases |
| `Tests/SpeedTestToolUITests.swift` | Speed test tool UI test cases |
| `Tests/WakeOnLANToolUITests.swift` | Wake-on-LAN tool UI test cases |
| `Tests/WebBrowserToolUITests.swift` | Web browser tool UI test cases |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Screens/` | Page object classes representing app screens |
| `Tests/` | Test cases for each screen/feature |

## For AI Agents

### Page Object Pattern

1. **Base Class:** All screen objects inherit from `BaseScreen` for common utilities.
2. **Screen Objects:** Encapsulate UI elements and actions for a specific screen.
3. **Test Files:** Import screen objects and write test scenarios using their methods.
4. **Accessibility Identifiers:** All interactions use identifiers following `{screen}_{element}_{descriptor}` convention.

### Common Utilities (BaseScreen)

- `waitForElement(_:timeout:)` - Wait for element to exist
- `tapIfExists(_:)` - Tap element if it exists
- `typeText(_:text:)` - Type text into text field
- `clearAndTypeText(_:text:)` - Clear field and type new text
- `swipeUp(on:)` / `swipeDown(on:)` - Swipe gestures
- `scrollToTop()` - Scroll to top of view
- `dismissKeyboard()` - Dismiss keyboard if visible
- `navigateToTab(_:)` - Switch to tab by name

### Running UI Tests

Run all UI tests:
```bash
xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Run specific UI test:
```bash
xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:NetmonitorUITests/DashboardUITests/testDashboardLoads
```

### Working Instructions

- **Adding Tests:** Create test class inheriting from `XCTestCase`, instantiate screen objects, write test methods.
- **Adding Screen Objects:** Create class inheriting from `BaseScreen`, define element accessors, add action methods.
- **Accessibility Identifiers:** Ensure all interactive elements in the app have identifiers matching the convention.
- **Timeouts:** Default timeout is 5 seconds. Override via `timeout` parameter or `BaseScreen` initializer.
- **Navigation:** Use `navigateToTab()` to switch tabs before testing specific screens.

### Dependencies

- XCTest framework
- Netmonitor app target (UI under test)

### Test Organization

Tests are organized by feature/screen:
- Dashboard tests verify connection status display
- Network Map tests verify device scanning and list display
- Tools tests verify navigation to each tool
- Settings tests verify preference changes
- Tool-specific tests verify each tool's functionality
