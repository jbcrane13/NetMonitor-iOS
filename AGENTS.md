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
| `tasks/` | Legacy task-tracking artifacts |
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


## Issue Tracking with GitHub Issues

Use GitHub Issues through the `gh` CLI as the single task tracker.

```bash
gh issue list --state open --json number,title,labels,assignees
gh issue create --title "Issue title" --body "Scope and acceptance criteria"
gh issue edit <number> --add-assignee "@me"
gh issue close <number> --comment "Done: <verified result>"
```

Read the complete issue and comments before starting. Use native sub-issues and blocking relationships for dependencies. Link delivery PRs with `Closes #<number>` when the work is complete.
