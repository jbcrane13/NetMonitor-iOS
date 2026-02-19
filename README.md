# NetMonitor Mobile

**Professional network diagnostics companion app for iPhone and iPad.**

[![Platform](https://img.shields.io/badge/platform-iOS%2018%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

NetMonitor Mobile puts a full suite of network diagnostic tools in your pocket. Scan your local network, monitor device status, run traceroutes, test speeds, and pair with [NetMonitor Pro](https://netmonitor.app) on your Mac for seamless cross-device monitoring.

---

## Screenshots

<!-- Add screenshots here -->
<!-- | Dashboard | Network Map | Tools | -->
<!-- |-----------|-------------|-------| -->
<!-- | ![Dashboard](docs/screenshots/dashboard.png) | ![Map](docs/screenshots/map.png) | ![Tools](docs/screenshots/tools.png) | -->

*Screenshots coming soon.*

---

## Features

### Network Scanner
Discover every device on your local network. NetMonitor Mobile combines ARP cache scanning, Bonjour/mDNS discovery, and TCP probing to find routers, computers, phones, smart home devices, printers, and more. Each device is identified with its hostname, IP address, MAC address, and vendor.

### Dashboard
Get a live overview of your network at a glance. Six information cards show your WiFi connection details (SSID, frequency, channel, security), gateway status with real-time latency, public IP and ISP info, monitored target status, and discovered device counts.

### Network Map
Visualize your network topology with a radial map centered on your gateway. Devices are color-coded by status — green for active, gray for idle, red for offline. Tap any device for detailed information and quick actions.

### Diagnostic Tools

NetMonitor Mobile includes 9 professional-grade network tools:

- **Ping** — ICMP echo with TCP fallback. Real-time round-trip statistics with min/max/average and packet loss tracking.
- **Traceroute** — UDP-based route tracing with progressive hop discovery and automatic hostname resolution.
- **Port Scanner** — TCP connect scanning with common port presets (Top 20, Web, Email, Database) and concurrent probing.
- **DNS Lookup** — Query A, AAAA, MX, TXT, CNAME, and NS records against any DNS server.
- **Speed Test** — Measure download speed, upload speed, and latency with progress reporting.
- **WHOIS Lookup** — Query domain and IP registration data with both parsed and raw output.
- **Wake on LAN** — Send magic packets to wake devices on your network. Pick a device or enter a MAC address manually.
- **Bonjour Browser** — Browse mDNS services on your network across 18+ service types with tiered discovery.
- **Web Browser** — Built-in browser for accessing device web interfaces and network portals.

### Set Target
Pick any router or host as your scan target. The selected target pre-fills tool inputs across the app, so you can quickly run diagnostics against a specific device without re-entering addresses.

### Router IP Detection
Automatically detects your network gateway with MAC address resolution, vendor identification, and real-time latency measurement.

### Companion Protocol
Pair with **NetMonitor Pro** on macOS via Bonjour for cross-device monitoring. Your Mac streams live network data — device lists, monitoring targets, speed test results — directly to your iPhone or iPad over the local network.

### Designed for iPhone and iPad
Clean SwiftUI interface with a translucent glass design system, optimized for both iPhone and iPad. Three-tab layout (Dashboard, Network Map, Tools) keeps everything one tap away.

---

## Requirements

- iPhone or iPad running **iOS 18.0** or later
- Xcode 16+ (for building from source)

---

## Installation

### From Source

```bash
git clone https://github.com/blakecrane/NetMonitor-iOS.git
cd NetMonitor-iOS/Netmonitor
xcodegen generate
open Netmonitor.xcodeproj
```

Select your target device or simulator and press **Cmd+R** to build and run.

### From the App Store

<!-- [**Download NetMonitor Mobile — $4.99**](https://apps.apple.com/app/netmonitor-mobile/id000000000) -->

*App Store link coming soon.*

---

## Architecture

NetMonitor Mobile is built with **SwiftUI** and follows the **MVVM** pattern with a protocol-oriented service layer.

```
Netmonitor/
├── App/            Entry point and tab navigation
├── Models/         SwiftData @Model classes and transient Codable types
├── ViewModels/     @MainActor @Observable view models (14 total)
├── Services/       Async network services with protocol interfaces (11 core services)
├── Views/          SwiftUI views organized by feature
│   ├── Dashboard/
│   ├── NetworkMap/
│   ├── Tools/
│   ├── Settings/
│   ├── DeviceDetail/
│   └── Components/
└── Utilities/      Theme system, settings, shared helpers
```

**Key patterns:**

- **Swift 6 strict concurrency** enforced project-wide (`SWIFT_STRICT_CONCURRENCY: complete`)
- **`async/await`** throughout the service layer with `AsyncStream` for real-time results
- **`@MainActor @Observable`** view models owned by views via `@State`
- **SwiftData** for persistent storage (devices, paired Macs, monitoring targets, tool results)
- **Protocol-oriented services** with dependency injection for testability
- **XcodeGen** for project file generation from a declarative `project.yml`

---

## Building

```bash
# Generate the Xcode project (required after changing project.yml)
cd Netmonitor && xcodegen generate

# Build
xcodebuild build -scheme Netmonitor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run tests
xcodebuild test -scheme Netmonitor \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

---

## Contributing

Contributions are welcome. Please open an issue to discuss proposed changes before submitting a pull request.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

Copyright 2026 Blake Crane.
