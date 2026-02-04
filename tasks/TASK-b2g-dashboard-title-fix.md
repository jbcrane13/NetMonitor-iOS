# Task: Fix Dashboard Title Overlap
**Bead:** NetMonitor-iOS-b2g
**Priority:** P0
**Type:** Bug Fix

## Problem
The large "Dashboard" navigation title overlaps with the Session card content. When viewing the Dashboard tab, the title text appears on top of the card's "Started" timestamp.

## Root Cause
- Using `.navigationBarTitleDisplayMode(.large)` with custom background
- `themedBackground()` modifier uses `.ignoresSafeArea()` which extends under nav bar
- ScrollView content doesn't account for the large title space

## Acceptance Criteria
- [ ] Dashboard title does NOT overlap with any card content
- [ ] Large title animates correctly when scrolling (collapses to inline)
- [ ] All other screens using large titles work correctly (Tools, NetworkMap if applicable)
- [ ] No visual regressions

## Files to Modify
- `Netmonitor/Netmonitor/Views/Dashboard/DashboardView.swift`
- Possibly `Netmonitor/Netmonitor/Utilities/Theme.swift` if the fix is in themedBackground

## Suggested Fix
Option A: Add top padding to ScrollView content that accounts for large title
```swift
ScrollView {
    VStack(spacing: Theme.Layout.sectionSpacing) {
        // ...
    }
    .padding(.top, 60) // Adjust value to not overlap with large title
    // ...
}
```

Option B: Use `.contentMargins()` or `.safeAreaInset()` (iOS 15+)

Option C: Remove `.ignoresSafeArea()` from themedBackground and handle background differently

## Verification Steps
1. Build: `xcodebuild build -project Netmonitor/Netmonitor.xcodeproj -scheme Netmonitor -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -quiet`
2. Run app and take screenshot
3. Verify title doesn't overlap content
4. Scroll to verify title collapse works
5. Check Tools and other screens with large titles

## Quality Gate
See /QUALITY_GATE.md
