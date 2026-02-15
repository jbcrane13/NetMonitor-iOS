<!-- Generated: 2026-01-29 | Updated: 2026-02-15 -->

# NetMonitor-iOS

## Purpose
An iOS 18+ network monitoring companion app built with SwiftUI, SwiftData, and Network.framework. Provides real-time network diagnostics, device discovery, and a suite of network tools (ping, port scan, DNS lookup, traceroute, WHOIS, Wake-on-LAN, Bonjour discovery, speed test).

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | Project-level instructions for AI agents (build commands, architecture, conventions) |
| `RELEASE-MANDATE.md` | Current release status, P0 blockers, priority order for fixes |
| `ARCHITECTURE-REVIEW.md` | Architecture analysis and design patterns |
| `README.md` | User-facing project documentation |
| `QA-REPORT.md` | Quality assurance testing results |
| `QUALITY_GATE.md` | Build and test quality gate definitions |
| `.gitignore` | Git ignore rules |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Netmonitor/` | Xcode project root containing XcodeGen config and all source code (see `Netmonitor/AGENTS.md`) |
| `docs/` | Product requirements, implementation plans, and design docs (see `docs/AGENTS.md`) |
| `Screenshots/` | App screenshots for documentation and App Store |
| `tasks/` | Task tracking files (legacy, now using beads) |
| `.beads/` | Beads issue tracking database (JSONL format) |
| `.omc/` | OMC (oh-my-claudecode) state and session data |
| `.claude/` | Claude Code configuration and project memory |

## For AI Agents

### Working In This Directory
- Read `CLAUDE.md` first for build commands, architecture overview, and conventions
- Build system uses XcodeGen — run `cd Netmonitor && xcodegen generate` if `project.yml` changes
- Build with: `xcodebuild build -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Test with: `xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

### Key Architecture
- **Swift 6** with strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`)
- **SwiftUI + SwiftData** for UI and persistence
- **@Observable** pattern for ViewModels (not ObservableObject)
- **async/await** throughout services, `actor` isolation for concurrent operations
- **Liquid Glass** design system in `Utilities/Theme.swift`

### Testing Requirements
- All changes must compile with zero warnings under strict concurrency
- Run unit tests before committing
- Unit tests: `xcodebuild test -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- UI tests available in `Netmonitor/NetmonitorUITests/`

### Build System
- **XcodeGen** for project generation (run `cd Netmonitor && xcodegen generate` after `project.yml` changes)
- **Swift Package Manager** for NetworkScanKit (local package in `Netmonitor/NetworkScanKit/`)

## Dependencies

### External
- iOS 18.0+ SDK
- Network.framework — connectivity monitoring, NWConnection
- SwiftData — persistence
- No third-party dependencies

### Internal Packages
- **NetworkScanKit** — Swift package for composable scan phases (ARP, Bonjour, TCP probe, SSDP, reverse DNS)

<!-- MANUAL: -->

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds


<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Auto-syncs to JSONL for version control
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update bd-42 --status in_progress --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task**: `bd update <id> --status in_progress`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Auto-Sync

bd automatically syncs with git:

- Exports to `.beads/issues.jsonl` after changes (5s debounce)
- Imports from JSONL when newer (e.g., after `git pull`)
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

<!-- END BEADS INTEGRATION -->
