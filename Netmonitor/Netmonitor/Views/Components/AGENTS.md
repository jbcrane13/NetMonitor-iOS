<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# Components

## Purpose
Reusable SwiftUI components implementing the Liquid Glass design system.

## Key Files
| File | Description |
|------|-------------|
| `GlassButton.swift` | Styled button with variants: primary, secondary, success, danger, ghost |
| `GlassCard.swift` | Card container with glass-morphism effect |
| `MetricCard.swift` | Compact card for displaying a single metric with label |
| `StatusBadge.swift` | Colored badge for connection/status indicators |
| `EmptyStateView.swift` | Placeholder for empty lists/results |
| `ToolInputField.swift` | Styled text input for tool host/address entry |
| `ToolRunButton.swift` | Execute button for network tools |
| `ToolResultRow.swift` | Single result row for tool output lists |
| `ToolStatisticsCard.swift` | Summary statistics card for tool results |

## For AI Agents

### Working In This Directory
- Components use `Theme` constants — never hardcode colors or spacing
- All components should accept accessibility identifier parameters
- Keep components generic and reusable across features
- Follow existing naming conventions: `Glass*` for design-system components, `Tool*` for tool-specific components

<!-- MANUAL: -->
