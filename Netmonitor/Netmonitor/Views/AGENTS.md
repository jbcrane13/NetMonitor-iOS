<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# Views

## Purpose
SwiftUI views organized by feature area. Each subdirectory corresponds to a tab or major feature.

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Dashboard/` | Main dashboard with network status overview (see `Dashboard/AGENTS.md`) |
| `NetworkMap/` | Device discovery and network topology view (see `NetworkMap/AGENTS.md`) |
| `Tools/` | Network tool views — ping, port scan, DNS, traceroute, etc. (see `Tools/AGENTS.md`) |
| `Components/` | Reusable UI components — cards, buttons, badges (see `Components/AGENTS.md`) |
| `Settings/` | App settings views |

## For AI Agents

### Working In This Directory
- Views own their ViewModel via `@State`
- Use components from `Components/` for consistent styling
- Apply `Theme` constants from `Utilities/Theme.swift`
- All interactive elements need accessibility identifiers: `{screen}_{element}_{descriptor}`
- Use `GlassCard` modifier and `GlassButton` for the Liquid Glass aesthetic

<!-- MANUAL: -->
