<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# NetworkMap

## Purpose
Network topology view showing discovered LAN devices and their relationships.

## Key Files
| File | Description |
|------|-------------|
| `NetworkMapView.swift` | Device list/map with discovery controls |

## For AI Agents

### Working In This Directory
- Uses `NetworkMapViewModel` for state
- Relies on `DeviceDiscoveryService` for LAN scanning
- Device data persisted via `LocalDevice` SwiftData model
- Accessibility prefix: `map_`

<!-- MANUAL: -->
