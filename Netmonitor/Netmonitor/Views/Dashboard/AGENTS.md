<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# Dashboard

## Purpose
Main dashboard tab showing real-time network status overview — connectivity, WiFi info, gateway latency, public IP/ISP details.

## Key Files
| File | Description |
|------|-------------|
| `DashboardView.swift` | Primary dashboard layout with status cards and metrics |

## For AI Agents

### Working In This Directory
- Uses `DashboardViewModel` for state
- Displays data from multiple services: NetworkMonitor, WiFiInfo, Gateway, PublicIP
- Use `MetricCard` and `GlassCard` components for consistent styling
- Accessibility prefix: `dashboard_`

<!-- MANUAL: -->
