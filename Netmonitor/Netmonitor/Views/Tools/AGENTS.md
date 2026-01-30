<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# Tools

## Purpose
Network diagnostic tool views. Each tool has its own view and corresponding ViewModel.

## Key Files
| File | Description |
|------|-------------|
| `ToolsView.swift` | Navigation hub listing all available tools |
| `PingToolView.swift` | TCP ping with streaming results |
| `PortScannerToolView.swift` | Port scanning interface |
| `DNSLookupToolView.swift` | DNS record query interface |
| `TracerouteToolView.swift` | Network path tracing display |
| `BonjourDiscoveryToolView.swift` | mDNS service browser |
| `WHOISToolView.swift` | WHOIS lookup interface |
| `WakeOnLANToolView.swift` | Magic packet sender |
| `SpeedTestToolView.swift` | Network speed test interface |

## For AI Agents

### Working In This Directory
- Each tool view follows the pattern: input field + run button + results list
- Use shared components: `ToolInputField`, `ToolRunButton`, `ToolResultRow`, `ToolStatisticsCard`
- Each view owns its ViewModel via `@State`
- Accessibility prefix: `tools_`
- Results can be persisted via `ToolResult` SwiftData model

<!-- MANUAL: -->
