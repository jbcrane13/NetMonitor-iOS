<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-02-15 -->

# Utilities

## Purpose
Shared utilities including the design system (Theme), view modifiers, and networking utilities.

## Key Files
| File | Description |
|------|-------------|
| `Theme.swift` | Liquid Glass design system — `Colors` (accent, success, error, glass variants), `Layout` (spacing, corner radii), `GlassButton` component |
| `ThemeManager.swift` | Theme state management — accent color persistence, app-wide theme coordination |
| `GlassCard.swift` | ViewModifier for consistent glass-morphism card styling with blur and border effects |
| `NetworkUtilities.swift` | IP address parsing, subnet calculations, CIDR notation, network range enumeration |

## For AI Agents

### Working In This Directory
- `Theme` is the single source of truth for all design tokens
- Use `Theme.Colors.*` for semantic colors, `Theme.Layout.*` for spacing
- `GlassCard` modifier should be applied to card containers for consistent visual style
- `GlassButton` provides pre-styled button variants: `.primary`, `.secondary`, `.success`, `.danger`, `.ghost`
- `ThemeManager` is `@MainActor @Observable` — use `.shared` singleton for accent color management
- Network utilities are used by Services — changes here may affect DeviceDiscoveryService, GatewayService, and tool ViewModels

### Design System
```swift
// Colors
Theme.Colors.accent         // User-configurable accent color (via ThemeManager)
Theme.Colors.accentDark
Theme.Colors.success / .successDark
Theme.Colors.error / .errorDark
Theme.Colors.glass / .glassDark / .glassAccent

// Layout
Theme.Layout.cardPadding
Theme.Layout.cornerRadius
Theme.Layout.spacing

// Components
GlassButton("Label", variant: .primary) { action }
  .modifier(GlassCard())
```

### Network Utilities
- IP address validation and parsing (IPv4/IPv6)
- Subnet mask calculations and CIDR conversion
- Network range enumeration for device discovery
- Gateway IP extraction from routing table

<!-- MANUAL: -->
