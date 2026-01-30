<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# Models

## Purpose
Data layer containing SwiftData persistent models and transient Codable types for network data.

## Key Files
| File | Description |
|------|-------------|
| `PairedMac.swift` | SwiftData model for paired Mac companions |
| `LocalDevice.swift` | SwiftData model for discovered LAN devices |
| `MonitoringTarget.swift` | SwiftData model for user-configured monitoring targets |
| `ToolResult.swift` | SwiftData model for persisted tool execution results (includes `SpeedTestResult`) |
| `NetworkModels.swift` | Transient types: `NetworkStatus`, `WiFiInfo`, `GatewayInfo`, `ISPInfo` |
| `ToolModels.swift` | Transient types: `PingResult`, `TracerouteHop`, `PortScanResult`, `DNSRecord`, `BonjourService` |
| `Enums.swift` | Shared enumerations used across the app |

## For AI Agents

### Working In This Directory
- SwiftData models use `@Model` macro — changes may require migration
- Transient types are plain `Codable` structs, not persisted
- All models must be `Sendable` for strict concurrency
- After adding/removing model properties, verify SwiftData container still initializes

### Persisted vs Transient
- **Persisted** (`@Model`): `PairedMac`, `LocalDevice`, `MonitoringTarget`, `ToolResult`, `SpeedTestResult`
- **Transient** (`Codable`): `NetworkStatus`, `WiFiInfo`, `GatewayInfo`, `ISPInfo`, `PingResult`, `TracerouteHop`, `PortScanResult`, `DNSRecord`, `BonjourService`

<!-- MANUAL: -->
