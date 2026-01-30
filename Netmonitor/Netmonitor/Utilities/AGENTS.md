<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# Utilities

## Purpose
Shared utilities including the design system (Theme), view modifiers, concurrency helpers, and networking utilities.

## Key Files
| File | Description |
|------|-------------|
| `Theme.swift` | Liquid Glass design system — colors, spacing, corner radii, typography |
| `GlassCard.swift` | ViewModifier for consistent glass-morphism card styling |
| `ConcurrencyHelpers.swift` | Async/await utility extensions |
| `NetworkUtilities.swift` | IP address parsing, subnet calculations, network helpers |

## For AI Agents

### Working In This Directory
- `Theme` is the single source of truth for all design tokens
- Use `Theme.Colors.*` for semantic colors, `Theme.Layout.*` for spacing
- `GlassCard` modifier should be applied to card containers
- Network utilities are used by Services — changes here may affect multiple services

<!-- MANUAL: -->
