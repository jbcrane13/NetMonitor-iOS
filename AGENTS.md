<!-- Generated: 2026-01-29 | Updated: 2026-01-29 -->

# NetMonitor-iOS

## Purpose
An iOS 18+ network monitoring companion app built with SwiftUI, SwiftData, and Network.framework. Provides real-time network diagnostics, device discovery, and a suite of network tools (ping, port scan, DNS lookup, traceroute, WHOIS, Wake-on-LAN, Bonjour discovery, speed test).

## Key Files
| File | Description |
|------|-------------|
| `CLAUDE.md` | Project-level instructions for AI agents (build commands, architecture, conventions) |
| `README.md` | User-facing project documentation |
| `.gitignore` | Git ignore rules |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `Netmonitor/` | Xcode project root containing XcodeGen config and all source code (see `Netmonitor/AGENTS.md`) |
| `docs/` | Product requirements, implementation plans, and design docs (see `docs/AGENTS.md`) |

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

## Dependencies

### External
- iOS 18.0+ SDK
- Network.framework — connectivity monitoring, NWConnection
- SwiftData — persistence
- No third-party dependencies

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
