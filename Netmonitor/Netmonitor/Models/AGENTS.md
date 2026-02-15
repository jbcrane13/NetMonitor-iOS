<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-02-15 -->

# Models

## Purpose
Data layer containing SwiftData persistent models and transient Codable types for network data.

## Key Files
| File | Description |
|------|-------------|
| `PairedMac.swift` | SwiftData model for paired Mac companions |
| `LocalDevice.swift` | SwiftData model for discovered LAN devices |
| `MonitoringTarget.swift` | SwiftData model for user-configured monitoring targets |
| `ToolResult.swift` | SwiftData model for persisted tool execution results |
| `NetworkModels.swift` | Transient types: `NetworkStatus`, `WiFiInfo`, `GatewayInfo`, `ISPInfo` |
| `ToolModels.swift` | Transient types: `PingResult`, `TracerouteHop`, `PortScanResult`, `DNSRecord`, `BonjourService`, `SpeedTestResult` |
| `Enums.swift` | Shared enumerations: `ConnectionType`, `DeviceType`, `StatusType`, `ToolType`, `DNSRecordType`, `ScanPhase` |
| `CompanionMessage.swift` | Codable types for Mac companion WebSocket protocol |
| `NetworkError.swift` | Custom error types for network operations |

## For AI Agents

### Working In This Directory
- SwiftData models use `@Model` macro — changes may require migration
- Transient types are plain `Codable` structs, not persisted
- All models must be `Sendable` for strict concurrency
- After adding/removing model properties, verify SwiftData container still initializes
- Error types conform to `LocalizedError` for user-facing messages

### Persisted vs Transient
- **Persisted** (`@Model`): `PairedMac`, `LocalDevice`, `MonitoringTarget`, `ToolResult`
- **Transient** (`Codable`): `NetworkStatus`, `WiFiInfo`, `GatewayInfo`, `ISPInfo`, `PingResult`, `TracerouteHop`, `PortScanResult`, `DNSRecord`, `BonjourService`, `SpeedTestResult`, `CompanionMessage`, `NetworkError`

### Key Enums
- `ConnectionType`: `.wifi`, `.cellular`, `.ethernet`, `.vpn`, `.other`
- `DeviceType`: `.router`, `.computer`, `.phone`, `.tablet`, `.iot`, `.printer`, `.tv`, `.gameConsole`, `.unknown`
- `StatusType`: `.excellent`, `.good`, `.fair`, `.poor`, `.offline`
- `ToolType`: `.ping`, `.portScan`, `.dnsLookup`, `.traceroute`, `.whois`, `.bonjour`, `.wol`, `.speedTest`
- `DNSRecordType`: `.a`, `.aaaa`, `.mx`, `.cname`, `.ns`, `.txt`, `.soa`, `.ptr`
- `ScanPhase`: `.ssdp`, `.bonjour`, `.tcp`, `.complete`

<!-- MANUAL: -->
