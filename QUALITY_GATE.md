# Quality Gate

Every PR must pass these checks before merging.

## Automated Checks
- [ ] Build succeeds (Debug + Release)
- [ ] All unit tests pass
- [ ] All UI tests pass (if applicable)
- [ ] No new SwiftLint warnings

## Manual Verification (by agent)
- [ ] Feature works as described in task
- [ ] UI matches design intent (screenshot comparison if UI change)
- [ ] No regressions in related functionality
- [ ] Accessibility identifiers added for new UI elements

## PR Requirements
- [ ] Clear description of what changed and why
- [ ] Evidence of verification (test output, screenshots)
- [ ] Self-review completed

## Commands
```bash
# Build
xcodebuild build -project Netmonitor/Netmonitor.xcodeproj -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -quiet

# Unit tests
xcodebuild test -project Netmonitor/Netmonitor.xcodeproj -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:NetmonitorTests

# UI tests
xcodebuild test -project Netmonitor/Netmonitor.xcodeproj -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:NetmonitorUITests

# Screenshot
xcrun simctl io booted screenshot /tmp/screenshot.png
```
