<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# Services

## Purpose
Network operation services implementing async/await patterns. Each service encapsulates a specific network capability.

## Key Files
| File | Description |
|------|-------------|
| `NetworkMonitorService.swift` | NWPathMonitor wrapper for connectivity status |
| `WiFiInfoService.swift` | SSID/BSSID detection (requires location permission) |
| `DeviceDiscoveryService.swift` | LAN device discovery via TCP probing with TaskGroup |
| `GatewayService.swift` | Default gateway detection and latency measurement |
| `PublicIPService.swift` | External IP and ISP info via public APIs |
| `PingService.swift` | TCP-based ping with AsyncStream results (actor-isolated) |
| `PortScannerService.swift` | TCP connect port scanning |
| `DNSLookupService.swift` | DNS record queries (A, AAAA, MX, CNAME, etc.) |
| `BonjourDiscoveryService.swift` | mDNS/Bonjour service browser |
| `WakeOnLANService.swift` | Magic packet UDP broadcast |
| `TracerouteService.swift` | Network path tracing |
| `WHOISService.swift` | WHOIS domain/IP lookups |

## For AI Agents

### Working In This Directory
- Services use `async/await` — never block the main thread
- `PingService` is an `actor` for safe concurrent access
- Services producing streaming results use `AsyncStream`
- Services are injected into ViewModels, not used directly by Views
- Use `NWConnection` from Network.framework for TCP/UDP operations

### Concurrency Patterns
- `actor` for shared mutable state (`PingService`)
- `TaskGroup` for parallel operations (`DeviceDiscoveryService`)
- `AsyncStream` for streaming results (ping, port scan)
- `@MainActor` on services that update UI-bound state

<!-- MANUAL: -->
