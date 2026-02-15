<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-02-15 -->

# Services

## Purpose
Network operation services implementing async/await patterns. Each service encapsulates a specific network capability.

## Key Files
| File | Description |
|------|-------------|
| `NetworkMonitorService.swift` | NWPathMonitor wrapper for connectivity status — **singleton `.shared`** |
| `WiFiInfoService.swift` | SSID/BSSID detection (requires location permission) |
| `DeviceDiscoveryService.swift` | LAN device discovery via multi-phase scan (SSDP, Bonjour, TCP) — **singleton `.shared`** |
| `GatewayService.swift` | Default gateway detection and latency measurement |
| `PublicIPService.swift` | External IP and ISP info via public APIs |
| `PingService.swift` | TCP-based ping with AsyncStream results, adaptive timeout — **actor** |
| `PortScannerService.swift` | TCP connect port scanning — **actor** |
| `DNSLookupService.swift` | DNS record queries (A, AAAA, MX, CNAME, TXT, NS, SOA, PTR) |
| `BonjourDiscoveryService.swift` | mDNS/Bonjour service browser with NetServiceBrowser |
| `WakeOnLANService.swift` | Magic packet UDP broadcast for Wake-on-LAN |
| `TracerouteService.swift` | Network path tracing — **actor** |
| `WHOISService.swift` | WHOIS domain/IP lookups via TCP socket — **actor** |
| `SpeedTestService.swift` | Download/upload bandwidth measurement with adaptive chunk sizing |
| `MacConnectionService.swift` | Paired Mac companion WebSocket connection with Bonjour discovery — **singleton `.shared`** |
| `BackgroundTaskService.swift` | BGTaskScheduler registration and execution for background refresh/sync |
| `NotificationService.swift` | Local notification delivery via UNUserNotificationCenter |
| `DataExportService.swift` | CSV/JSON export of scan results and tool outputs |
| `MACVendorLookupService.swift` | MAC address to vendor name lookup via embedded OUI database |
| `ServiceProtocols.swift` | Protocol definitions for all services (dependency injection contracts) |

## For AI Agents

### Working In This Directory
- **Singleton pattern**: `NetworkMonitorService.shared`, `MacConnectionService.shared`, `DeviceDiscoveryService.shared` are singletons — do not instantiate
- Services use `async/await` — never block the main thread
- Actor-isolated services: `PingService`, `PortScannerService`, `TracerouteService`, `WHOISService`
- Services producing streaming results use `AsyncStream`
- Services are injected into ViewModels, not used directly by Views
- Use `NWConnection` from Network.framework for TCP/UDP operations

### Concurrency Patterns
- **Singleton services** (`@MainActor @Observable` or actor): NetworkMonitorService, MacConnectionService, DeviceDiscoveryService
- **Actor** for concurrent background ops: PingService, PortScannerService, TracerouteService, WHOISService
- **TaskGroup** for parallel operations (DeviceDiscoveryService — up to 20 concurrent TCP probes)
- **AsyncStream** for streaming results (ping, port scan, traceroute)
- **Static utilities** (no state): BackgroundTaskService, NotificationService, DataExportService, MACVendorLookupService

### Recent Architectural Changes
- **NetworkMonitorService**: Now singleton `.shared` (was instantiated per ViewModel)
- **PingService**: Added adaptive timeout logic (1s → 2s → 5s based on success rate)
- **DeviceDiscoveryService**: Multi-phase scan pipeline (SSDP overlap with Bonjour, then TCP with thermal throttling)
- **MacConnectionService**: Bonjour-based auto-discovery with fallback to manual IP

<!-- MANUAL: -->
