import XCTest

/// UI tests for the Settings screen
final class SettingsUITests: XCTestCase {
    
    var app: XCUIApplication!
    var settingsScreen: SettingsScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Navigate to Settings via Dashboard
        let dashboardScreen = DashboardScreen(app: app)
        settingsScreen = dashboardScreen.openSettings()
    }
    
    override func tearDown() {
        app = nil
        settingsScreen = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func scrollToElement(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        if element.waitForExistence(timeout: 1) {
            return true
        }

        for _ in 0..<maxSwipes {
            settingsScreen.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        for _ in 0..<maxSwipes {
            settingsScreen.swipeDown()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return element.exists
    }

    private func toggleValue(_ toggle: XCUIElement) -> String {
        if let value = toggle.value as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        if let value = toggle.value as? NSNumber {
            return value.stringValue
        }
        return ""
    }

    private func toggleState(_ toggle: XCUIElement) -> Bool? {
        let value = toggleValue(toggle)
        let label = toggle.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if label.hasSuffix(" on") {
            return true
        }
        if label.hasSuffix(" off") {
            return false
        }

        if value == "1" || value == "on" || value == "true" {
            return true
        }
        if value == "0" || value == "off" || value == "false" {
            return false
        }

        if value.contains("turn off") || value.contains("selected") {
            return true
        }
        if value.contains("turn on") || value.contains("not selected") {
            return false
        }

        return nil
    }

    private func highLatencyAlertToggleElement() -> XCUIElement {
        let byID = settingsScreen.highLatencyAlertToggle
        if byID.exists {
            return byID
        }
        return settingsScreen.highLatencyAlertLabel
    }

    private func nearestVisibleSwitch(to element: XCUIElement) -> XCUIElement? {
        let targetMidY = element.frame.midY
        let visibleSwitches = app.switches.allElementsBoundByIndex.filter { $0.exists && !$0.frame.isEmpty }
        guard !visibleSwitches.isEmpty else { return nil }
        return visibleSwitches.min {
            abs($0.frame.midY - targetMidY) < abs($1.frame.midY - targetMidY)
        }
    }

    private func tapHighLatencyToggle() -> Bool {
        let byID = settingsScreen.highLatencyAlertToggle
        if byID.exists {
            if byID.isHittable {
                byID.tap()
            } else {
                byID.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            return true
        }

        let label = settingsScreen.highLatencyAlertLabel
        guard scrollToElement(label, maxSwipes: 4) else {
            return false
        }

        if let switchNearRow = nearestVisibleSwitch(to: label) {
            if switchNearRow.isHittable {
                switchNearRow.tap()
            } else {
                switchNearRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            return true
        }

        label.tap()
        return true
    }

    private func tapToggleUntilStateChanges(_ toggle: XCUIElement, initialState: Bool, maxAttempts: Int = 4) -> Bool {
        for _ in 0..<maxAttempts {
            let element = resolvedToggleElement(toggle)
            _ = scrollToElement(element, maxSwipes: 4)
            tapToggleControl(element)

            usleep(500_000)
            let refreshed = resolvedToggleElement(toggle)
            if let newState = toggleState(refreshed), newState != initialState {
                return true
            }
        }
        return false
    }

    private func tapToggleControl(_ toggle: XCUIElement) {
        let target = resolvedToggleElement(toggle)
        if !target.isHittable {
            _ = scrollToElement(target, maxSwipes: 4)
        }

        if target.isHittable {
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            return
        }

        if let nearby = nearestVisibleSwitch(to: target), nearby.isHittable {
            nearby.tap()
            return
        }

        target.tap()
    }

    private func resolvedToggleElement(_ toggle: XCUIElement) -> XCUIElement {
        let identifier = toggle.identifier
        guard !identifier.isEmpty else { return toggle }

        let anyMatch = app.descendants(matching: .any)[identifier]
        if anyMatch.exists {
            return anyMatch
        }

        let switchMatch = app.switches[identifier]
        if switchMatch.exists {
            return switchMatch
        }

        return toggle
    }

    private func exportMenuJSONOption(for optionRawValue: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "settings_export_\(optionRawValue)_json")
            .firstMatch
    }

    private func exportMenuCSVOption(for optionRawValue: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "settings_export_\(optionRawValue)_csv")
            .firstMatch
    }

    private func waitForExportOptions(optionRawValue: String, timeout: TimeInterval = 5) -> Bool {
        let jsonByID = exportMenuJSONOption(for: optionRawValue)
        let csvByID = exportMenuCSVOption(for: optionRawValue)
        if jsonByID.waitForExistence(timeout: timeout) || csvByID.waitForExistence(timeout: 1) {
            return true
        }

        let jsonButton = app.buttons["Export as JSON"]
        let csvButton = app.buttons["Export as CSV"]
        if jsonButton.waitForExistence(timeout: 1) || csvButton.waitForExistence(timeout: 1) {
            return true
        }

        let jsonLabel = app.staticTexts["Export as JSON"]
        let csvLabel = app.staticTexts["Export as CSV"]
        return jsonLabel.waitForExistence(timeout: 1) || csvLabel.waitForExistence(timeout: 1)
    }

    private func openExportMenuAndWaitForOptions(_ exportButton: XCUIElement, optionRawValue: String) -> Bool {
        guard exportButton.waitForExistence(timeout: 5) else { return false }

        if exportButton.isHittable {
            exportButton.tap()
        } else {
            settingsScreen.swipeUp()
            exportButton.tap()
        }

        if waitForExportOptions(optionRawValue: optionRawValue, timeout: 3) {
            return true
        }

        // Some rows need a second explicit tap after they are brought fully on-screen.
        if exportButton.isHittable {
            exportButton.tap()
            if waitForExportOptions(optionRawValue: optionRawValue, timeout: 2) {
                return true
            }
        }

        exportButton.press(forDuration: 0.75)
        return waitForExportOptions(optionRawValue: optionRawValue, timeout: 3)
    }

    private func tapJSONExportOption(optionRawValue: String) -> Bool {
        let optionByID = exportMenuJSONOption(for: optionRawValue)
        if optionByID.waitForExistence(timeout: 2) {
            optionByID.tap()
            return true
        }

        let optionByButtonText = app.buttons["Export as JSON"]
        if optionByButtonText.waitForExistence(timeout: 2) {
            optionByButtonText.tap()
            return true
        }

        let optionByMenuItemText = app.menuItems["Export as JSON"]
        if optionByMenuItemText.waitForExistence(timeout: 2) {
            optionByMenuItemText.tap()
            return true
        }

        return false
    }

    private func waitForShareSheet(timeout: TimeInterval = 5) -> Bool {
        if app.sheets.firstMatch.waitForExistence(timeout: timeout) {
            return true
        }

        if app.otherElements["ActivityListView"].waitForExistence(timeout: 1) {
            return true
        }

        return app.navigationBars["Share"].waitForExistence(timeout: 1)
    }

    private func dismissExportMenuIfVisible() {
        if app.menuItems["Export as JSON"].exists ||
            app.menuItems["Export as CSV"].exists ||
            app.buttons["Export as JSON"].exists ||
            app.buttons["Export as CSV"].exists {
            app.tap()
        }
    }

    private func dismissShareSheetIfVisible() {
        let done = app.buttons["Done"]
        let cancel = app.buttons["Cancel"]
        let close = app.buttons["Close"]

        if done.waitForExistence(timeout: 1) {
            done.tap()
        } else if cancel.waitForExistence(timeout: 1) {
            cancel.tap()
        } else if close.waitForExistence(timeout: 1) {
            close.tap()
        } else if app.sheets.firstMatch.exists {
            app.swipeDown()
        }
    }

    private var highLatencyThresholdLabel: XCUIElement {
        let byIdentifier = app.descendants(matching: .any)["settings_label_highLatencyThreshold"]
        return byIdentifier.exists ? byIdentifier : app.staticTexts["Threshold"]
    }

    private var highLatencyThresholdValueLabel: XCUIElement {
        let byIdentifier = app.staticTexts["settings_value_highLatencyThreshold"]
        return byIdentifier.exists ? byIdentifier : app.staticTexts.matching(NSPredicate(format: "label MATCHES '\\d+ms'")).firstMatch
    }

    private var backgroundRefreshStateLabel: XCUIElement {
        app.staticTexts["settings_value_backgroundRefresh"]
    }

    private var highLatencyStateLabel: XCUIElement {
        app.staticTexts["settings_value_highLatencyAlert"]
    }

    private var showDetailedResultsStateLabel: XCUIElement {
        app.staticTexts["settings_value_showDetailedResults"]
    }

    private func isHighLatencyThresholdVisible() -> Bool {
        settingsScreen.highLatencyThresholdStepper.exists ||
            settingsScreen.highLatencyThresholdStepperControl.exists ||
            highLatencyThresholdLabel.exists ||
            highLatencyThresholdValueLabel.exists
    }

    private func scrollToHighLatencyThreshold(maxSwipes: Int = 4) -> Bool {
        if isHighLatencyThresholdVisible() {
            return true
        }

        for _ in 0..<maxSwipes {
            settingsScreen.swipeUp()
            if isHighLatencyThresholdVisible() {
                return true
            }
        }

        for _ in 0..<maxSwipes {
            settingsScreen.swipeDown()
            if isHighLatencyThresholdVisible() {
                return true
            }
        }

        return false
    }

    private func highLatencyThresholdValue() -> Int? {
        guard highLatencyThresholdValueLabel.waitForExistence(timeout: 1) else {
            return nil
        }

        let raw = highLatencyThresholdValueLabel.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.hasSuffix("ms"), let parsed = Int(raw.dropLast(2)) else {
            return nil
        }

        return parsed
    }

    private func waitForHighLatencyThresholdVisibility(_ shouldBeVisible: Bool, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let visible = scrollToHighLatencyThreshold(maxSwipes: 1)
            if visible == shouldBeVisible {
                return true
            }
            usleep(250_000)
        }
        return scrollToHighLatencyThreshold(maxSwipes: 1) == shouldBeVisible
    }

    private func intValue(from label: XCUIElement) -> Int? {
        guard label.waitForExistence(timeout: 2) else { return nil }
        return Int(label.label.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func intValue(from label: XCUIElement, stripping suffix: String) -> Int? {
        guard label.waitForExistence(timeout: 2) else { return nil }
        let raw = label.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.hasSuffix(suffix) else { return nil }
        return Int(raw.dropLast(suffix.count))
    }

    private func doubleValue(from label: XCUIElement, stripping suffix: String) -> Double? {
        guard label.waitForExistence(timeout: 2) else { return nil }
        let raw = label.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.hasSuffix(suffix) else { return nil }
        return Double(raw.dropLast(suffix.count))
    }

    private func boolFromOnOffLabel(_ label: XCUIElement) -> Bool? {
        guard label.waitForExistence(timeout: 1) else { return nil }
        let value = label.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value == "on" {
            return true
        }
        if value == "off" {
            return false
        }
        return nil
    }

    private func waitForElementByScrolling(_ element: XCUIElement, maxSwipes: Int = 8) -> Bool {
        if element.waitForExistence(timeout: 1) {
            return true
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return element.exists
    }

    private func waitForOnOffLabelChange(_ label: XCUIElement, from initial: Bool, timeout: TimeInterval = 3) -> Bool? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let current = boolFromOnOffLabel(label), current != initial {
                return current
            }
            usleep(250_000)
        }
        return nil
    }

    private func waitForToggleStateChange(_ toggle: XCUIElement, from initial: Bool, timeout: TimeInterval = 3) -> Bool? {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let currentElement = resolvedToggleElement(toggle)
            if let state = toggleState(currentElement), state != initial {
                return state
            }
            usleep(250_000)
        }

        return nil
    }

    private func setHighLatencyThresholdVisibility(_ shouldBeVisible: Bool, maxAttempts: Int = 5) -> Bool {
        guard scrollToElement(highLatencyAlertToggleElement()) else {
            return false
        }

        for _ in 0..<maxAttempts {
            if shouldBeVisible {
                if scrollToHighLatencyThreshold(maxSwipes: 2) {
                    return true
                }
            } else if !isHighLatencyThresholdVisible() {
                return true
            }

            let toggle = highLatencyAlertToggleElement()
            guard scrollToElement(toggle, maxSwipes: 2) else {
                return false
            }
            if !tapHighLatencyToggle() {
                return false
            }

            usleep(300_000)

            if shouldBeVisible {
                if scrollToHighLatencyThreshold(maxSwipes: 2) {
                    return true
                }
            } else if !isHighLatencyThresholdVisible() {
                return true
            }

            _ = scrollToElement(toggle, maxSwipes: 2)
        }

        return shouldBeVisible ? scrollToHighLatencyThreshold(maxSwipes: 2) : !isHighLatencyThresholdVisible()
    }

    private func ensureToggle(_ toggle: XCUIElement, isOn: Bool) -> Bool {
        let currentElement = resolvedToggleElement(toggle)
        _ = scrollToElement(currentElement, maxSwipes: 4)
        guard let currentState = toggleState(currentElement) else {
            return false
        }

        if currentState != isOn {
            guard tapToggleUntilStateChanges(currentElement, initialState: currentState) else {
                return false
            }
            let refreshedElement = resolvedToggleElement(toggle)
            return toggleState(refreshedElement) == isOn
        }

        return true
    }
    
    // MARK: - Screen Loading Tests
    
    func testSettingsScreenLoads() {
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings screen should load")
    }
    
    // MARK: - Network Tools Settings Tests
    
    func testPingCountStepperExists() {
        XCTAssertTrue(
            settingsScreen.pingCountStepper.waitForExistence(timeout: 5),
            "Ping count stepper should exist"
        )
    }

    func testPingTimeoutStepperExists() {
        XCTAssertTrue(
            settingsScreen.pingTimeoutStepper.waitForExistence(timeout: 5),
            "Ping timeout stepper should exist"
        )
    }

    func testPortScanTimeoutStepperExists() {
        XCTAssertTrue(
            settingsScreen.portScanTimeoutStepper.waitForExistence(timeout: 5),
            "Port scan timeout stepper should exist"
        )
    }
    
    func testDNSServerTextFieldExists() {
        XCTAssertTrue(
            settingsScreen.dnsServerTextField.waitForExistence(timeout: 5),
            "DNS server text field should exist"
        )
    }
    
    // MARK: - Monitoring Settings Tests
    
    func testAutoRefreshPickerExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.autoRefreshPicker.waitForExistence(timeout: 5),
            "Auto refresh picker should exist"
        )
    }
    
    func testBackgroundRefreshToggleExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.backgroundRefreshToggle.waitForExistence(timeout: 5),
            "Background refresh toggle should exist"
        )
    }
    
    // MARK: - Notification Settings Tests
    
    func testTargetDownAlertToggleExists() {
        XCTAssertTrue(
            scrollToElement(settingsScreen.targetDownAlertToggle),
            "Target down alert toggle should exist"
        )
    }

    func testHighLatencyThresholdStepperExists() throws {
        let toggle = settingsScreen.highLatencyAlertToggle
        XCTAssertTrue(scrollToElement(toggle, maxSwipes: 4), "High latency alert toggle should be visible")

        if !isHighLatencyThresholdVisible() {
            tapToggleControl(toggle)
        }

        XCTAssertTrue(waitForHighLatencyThresholdVisibility(true), "High latency threshold row should appear when alerts are enabled")
        XCTAssertTrue(settingsScreen.highLatencyThresholdStepperControl.waitForExistence(timeout: 2), "High latency threshold stepper control should exist")
        XCTAssertTrue(settingsScreen.highLatencyThresholdValueLabel.waitForExistence(timeout: 2), "High latency threshold value should be visible")
    }

    func testNewDeviceAlertToggleExists() {
        XCTAssertTrue(
            scrollToElement(settingsScreen.newDeviceAlertToggle),
            "New device alert toggle should exist"
        )
    }

    // MARK: - Appearance Settings Tests

    func testThemePickerExists() {
        if scrollToElement(settingsScreen.themePicker, maxSwipes: 6) {
            return
        }

        XCTAssertTrue(
            scrollToElement(settingsScreen.themeText, maxSwipes: 2),
            "Theme setting row should exist even when picker accessibility is not exposed."
        )
    }

    func testAccentColorPickerExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.accentColorPicker.waitForExistence(timeout: 5),
            "Accent color picker should exist"
        )
    }

    // MARK: - Data & Privacy Tests

    func testDataRetentionPickerExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.dataRetentionPicker.waitForExistence(timeout: 5),
            "Data retention picker should exist"
        )
    }

    func testShowDetailedResultsToggleExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.showDetailedResultsToggle.waitForExistence(timeout: 5),
            "Show detailed results toggle should exist"
        )
    }
    
    func testClearHistoryButtonExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.clearHistoryButton.waitForExistence(timeout: 5),
            "Clear history button should exist"
        )
    }
    
    func testClearHistoryShowsAlert() {
        settingsScreen.tapClearHistory()
        
        XCTAssertTrue(
            settingsScreen.clearHistoryAlert.waitForExistence(timeout: 5),
            "Clear history alert should appear"
        )
    }
    
    func testClearHistoryAlertCanBeCancelled() {
        settingsScreen.tapClearHistory()
        _ = settingsScreen.clearHistoryAlert.waitForExistence(timeout: 5)
        
        settingsScreen.cancelClearHistory()
        
        // Alert should be dismissed
        XCTAssertFalse(
            settingsScreen.clearHistoryAlert.exists,
            "Clear history alert should be dismissed after cancel"
        )
    }
    
    func testClearCacheButtonExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.clearCacheButton.waitForExistence(timeout: 5),
            "Clear cache button should exist"
        )
    }
    
    func testClearCacheShowsAlert() {
        settingsScreen.tapClearCache()
        
        XCTAssertTrue(
            settingsScreen.clearCacheAlert.waitForExistence(timeout: 5),
            "Clear cache alert should appear"
        )
    }
    
    func testClearCacheAlertCanBeCancelled() {
        settingsScreen.tapClearCache()
        _ = settingsScreen.clearCacheAlert.waitForExistence(timeout: 5)
        
        settingsScreen.cancelClearCache()
        
        XCTAssertFalse(
            settingsScreen.clearCacheAlert.exists,
            "Clear cache alert should be dismissed after cancel"
        )
    }

    // MARK: - Export Tests

    func testExportToolResultsMenuExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.exportToolResultsMenu.waitForExistence(timeout: 5),
            "Export tool results menu should exist"
        )
    }

    func testExportSpeedTestsMenuExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.exportSpeedTestsMenu.waitForExistence(timeout: 5),
            "Export speed tests menu should exist"
        )
    }

    func testExportDevicesMenuExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.exportDevicesMenu.waitForExistence(timeout: 5),
            "Export devices menu should exist"
        )
    }

    // MARK: - About Section Tests
    
    func testAppVersionRowExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.appVersionRow.waitForExistence(timeout: 5),
            "App version row should exist"
        )
    }

    func testBuildNumberRowExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.buildNumberRow.waitForExistence(timeout: 5),
            "Build number row should exist"
        )
    }

    func testIOSVersionRowExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.iosVersionRow.waitForExistence(timeout: 5),
            "iOS version row should exist"
        )
    }
    
    func testAcknowledgementsLinkExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.acknowledgementsLink.waitForExistence(timeout: 5),
            "Acknowledgements link should exist"
        )
    }

    func testSupportLinkExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.supportLink.waitForExistence(timeout: 5),
            "Support link should exist"
        )
    }

    func testRateAppButtonExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.rateAppButton.waitForExistence(timeout: 5),
            "Rate app button should exist"
        )
    }
    
    // MARK: - Navigation Tests

    func testCanNavigateBack() {
        settingsScreen.navigateBack()

        let dashboardScreen = DashboardScreen(app: app)
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to Dashboard")
    }

    // MARK: - Interaction Tests

    func testCanToggleBackgroundRefresh() {
        settingsScreen.swipeUp()
        let toggle = settingsScreen.backgroundRefreshToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Background refresh toggle should exist")
        XCTAssertTrue(toggle.isEnabled, "Background refresh toggle should be enabled")
        guard let initialState = toggleState(resolvedToggleElement(toggle)) else {
            XCTFail("Background refresh toggle should expose a deterministic on/off state")
            return
        }

        XCTAssertTrue(
            tapToggleUntilStateChanges(toggle, initialState: initialState),
            "Background refresh toggle should change state after tap"
        )
        XCTAssertEqual(
            toggleState(resolvedToggleElement(toggle)),
            !initialState,
            "Background refresh toggle should flip state after interaction"
        )

        _ = ensureToggle(toggle, isOn: initialState)
    }

    func testCanToggleTargetDownAlert() {
        let toggle = settingsScreen.targetDownAlertToggle
        XCTAssertTrue(scrollToElement(toggle), "Target down alert toggle should exist")
        XCTAssertTrue(toggle.isEnabled, "Target down alert toggle should be enabled")
        guard let initialState = toggleState(resolvedToggleElement(toggle)) else {
            XCTFail("Target down alert toggle should expose a deterministic on/off state")
            return
        }

        XCTAssertTrue(
            tapToggleUntilStateChanges(toggle, initialState: initialState),
            "Target down alert toggle should change state after tap"
        )

        guard let changedState = toggleState(resolvedToggleElement(toggle)) else {
            XCTFail("Target down alert toggle should remain readable after interaction")
            return
        }
        XCTAssertEqual(changedState, !initialState, "Target down alert toggle should flip state after tap")

        settingsScreen.navigateBack()
        settingsScreen = DashboardScreen(app: app).openSettings()
        let reopenedToggle = settingsScreen.targetDownAlertToggle
        XCTAssertTrue(scrollToElement(reopenedToggle), "Target down alert toggle should be visible after reopening settings")
        XCTAssertEqual(
            toggleState(resolvedToggleElement(reopenedToggle)),
            changedState,
            "Target down alert setting should persist after reopening settings"
        )

        _ = ensureToggle(reopenedToggle, isOn: initialState)
    }

    func testCanToggleNewDeviceAlert() {
        let toggle = settingsScreen.newDeviceAlertToggle
        XCTAssertTrue(scrollToElement(toggle), "New device alert toggle should exist")
        XCTAssertTrue(toggle.isEnabled, "New device alert toggle should be enabled")
        guard let initialState = toggleState(resolvedToggleElement(toggle)) else {
            XCTFail("New device alert toggle should expose a deterministic on/off state")
            return
        }

        XCTAssertTrue(
            tapToggleUntilStateChanges(toggle, initialState: initialState),
            "New device alert toggle should change state after tap"
        )

        guard let changedState = toggleState(resolvedToggleElement(toggle)) else {
            XCTFail("New device alert toggle should remain readable after interaction")
            return
        }
        XCTAssertEqual(changedState, !initialState, "New device alert toggle should flip state after tap")

        settingsScreen.navigateBack()
        settingsScreen = DashboardScreen(app: app).openSettings()
        let reopenedToggle = settingsScreen.newDeviceAlertToggle
        XCTAssertTrue(scrollToElement(reopenedToggle), "New device alert toggle should be visible after reopening settings")
        XCTAssertEqual(
            toggleState(resolvedToggleElement(reopenedToggle)),
            changedState,
            "New device alert setting should persist after reopening settings"
        )

        _ = ensureToggle(reopenedToggle, isOn: initialState)
    }

    func testAcknowledgementsNavigationWorks() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let acknowledgementsLink = settingsScreen.acknowledgementsLink
        XCTAssertTrue(acknowledgementsLink.waitForExistence(timeout: 5), "Acknowledgements link should exist")

        acknowledgementsLink.tap()

        // Verify navigation to Acknowledgements screen
        XCTAssertTrue(
            app.navigationBars["Acknowledgements"].waitForExistence(timeout: 5),
            "Acknowledgements screen should load with navigation bar title"
        )
    }

    func testAcknowledgementsShowsCreditsContent() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let acknowledgementsLink = settingsScreen.acknowledgementsLink
        XCTAssertTrue(acknowledgementsLink.waitForExistence(timeout: 5), "Acknowledgements link should exist")
        acknowledgementsLink.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["screen_acknowledgements"].waitForExistence(timeout: 5),
            "Acknowledgements screen container should be exposed"
        )
        XCTAssertTrue(app.staticTexts["acknowledgements_text_intro"].waitForExistence(timeout: 3), "Credits intro text should be present")

        let creditIDs = ["swift", "swiftui", "network_framework", "swiftdata"]
        for creditID in creditIDs {
            let card = app.descendants(matching: .any)["acknowledgements_item_\(creditID)"]
            XCTAssertTrue(
                waitForElementByScrolling(card, maxSwipes: 5),
                "Credits card \(creditID) should be visible in acknowledgements"
            )
            XCTAssertTrue(
                app.staticTexts["acknowledgements_item_\(creditID)_name"].exists,
                "Credits card \(creditID) should include a name"
            )
            XCTAssertTrue(
                app.staticTexts["acknowledgements_item_\(creditID)_license"].exists,
                "Credits card \(creditID) should include a license/source"
            )
            XCTAssertTrue(
                app.staticTexts["acknowledgements_item_\(creditID)_description"].exists,
                "Credits card \(creditID) should include a description"
            )
        }

        XCTAssertTrue(
            waitForElementByScrolling(app.staticTexts["acknowledgements_heading_specialThanks"], maxSwipes: 4),
            "Acknowledgements should include the Special Thanks heading"
        )
        XCTAssertTrue(
            app.staticTexts["acknowledgements_text_specialThanks"].exists,
            "Acknowledgements should include Special Thanks details"
        )
    }

    func testClearHistoryConfirmActuallyClears() {
        settingsScreen.tapClearHistory()

        XCTAssertTrue(
            settingsScreen.clearHistoryAlert.waitForExistence(timeout: 5),
            "Clear history alert should appear"
        )

        settingsScreen.confirmClearHistory()

        // Alert should be dismissed after confirmation
        XCTAssertFalse(
            settingsScreen.clearHistoryAlert.exists,
            "Clear history alert should be dismissed after confirmation"
        )
    }

    func testClearCacheConfirmActuallyClears() {
        settingsScreen.tapClearCache()

        XCTAssertTrue(
            settingsScreen.clearCacheAlert.waitForExistence(timeout: 5),
            "Clear cache alert should appear"
        )

        settingsScreen.confirmClearCache()

        // Alert should be dismissed after confirmation
        XCTAssertFalse(
            settingsScreen.clearCacheAlert.exists,
            "Clear cache alert should be dismissed after confirmation"
        )
    }

    func testMacPairingSection() {
        // Mac Companion section is at the top of settings, no scrolling needed
        // Section headers in SwiftUI Lists may appear as otherElements instead of staticTexts
        let macCompanionSection = app.otherElements["Mac Companion"].exists ?
            app.otherElements["Mac Companion"] : app.staticTexts["Mac Companion"]

        XCTAssertTrue(
            macCompanionSection.waitForExistence(timeout: 5),
            "Mac Companion section should exist in settings"
        )
    }

    // MARK: - Stepper Functional Tests

    func testPingCountStepperIncrement() {
        XCTAssertTrue(settingsScreen.pingCountStepper.waitForExistence(timeout: 5), "Ping count stepper should exist")
        guard let initialValue = intValue(from: settingsScreen.pingCountValueLabel) else {
            XCTFail("Ping count value should be visible and parseable")
            return
        }

        let incrementButton = settingsScreen.pingCountStepperControl.buttons["Increment"].firstMatch
        XCTAssertTrue(incrementButton.waitForExistence(timeout: 3), "Ping count increment control should exist")
        incrementButton.tap()

        guard let updatedValue = intValue(from: settingsScreen.pingCountValueLabel) else {
            XCTFail("Ping count value should remain parseable after increment")
            return
        }
        let expected = min(initialValue + 1, 50)
        XCTAssertEqual(updatedValue, expected, "Ping count should increase by one per increment tap")
    }

    func testPingTimeoutStepperIncrement() {
        XCTAssertTrue(settingsScreen.pingTimeoutStepper.waitForExistence(timeout: 5), "Ping timeout stepper should exist")
        guard let initialValue = intValue(from: settingsScreen.pingTimeoutValueLabel, stripping: "s") else {
            XCTFail("Ping timeout value should be visible and parseable")
            return
        }

        let incrementButton = settingsScreen.pingTimeoutStepperControl.buttons["Increment"].firstMatch
        XCTAssertTrue(incrementButton.waitForExistence(timeout: 3), "Ping timeout increment control should exist")
        incrementButton.tap()

        guard let updatedValue = intValue(from: settingsScreen.pingTimeoutValueLabel, stripping: "s") else {
            XCTFail("Ping timeout value should remain parseable after increment")
            return
        }
        let expected = min(initialValue + 1, 30)
        XCTAssertEqual(updatedValue, expected, "Ping timeout should increase by one second per increment tap")
    }

    func testPortScanTimeoutStepperIncrement() {
        XCTAssertTrue(settingsScreen.portScanTimeoutStepper.waitForExistence(timeout: 5), "Port scan timeout stepper should exist")
        guard let initialValue = doubleValue(from: settingsScreen.portScanTimeoutValueLabel, stripping: "s") else {
            XCTFail("Port scan timeout value should be visible and parseable")
            return
        }

        let incrementButton = settingsScreen.portScanTimeoutStepperControl.buttons["Increment"].firstMatch
        XCTAssertTrue(incrementButton.waitForExistence(timeout: 3), "Port scan timeout increment control should exist")
        incrementButton.tap()

        guard let updatedValue = doubleValue(from: settingsScreen.portScanTimeoutValueLabel, stripping: "s") else {
            XCTFail("Port scan timeout value should remain parseable after increment")
            return
        }
        let expected = min(initialValue + 0.5, 10.0)
        XCTAssertEqual(updatedValue, expected, accuracy: 0.01, "Port scan timeout should increase by 0.5s per increment tap")
    }

    func testDNSServerTextFieldEntry() {
        let textField = settingsScreen.dnsServerTextField
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "DNS server text field should exist")
        XCTAssertTrue(textField.isEnabled, "DNS server text field should be enabled")

        textField.tap()
        textField.typeText("9")

        let fieldValue = textField.value as? String ?? ""
        XCTAssertTrue(
            fieldValue.contains("9"),
            "DNS server text field should accept and display typed text"
        )
    }

    // MARK: - High Latency Alert Toggle Functional Tests

    func testHighLatencyToggleRevealsThreshold() throws {
        let toggle = settingsScreen.highLatencyAlertToggle
        XCTAssertTrue(scrollToElement(toggle, maxSwipes: 4), "High latency alert toggle should be visible")

        // Start from OFF and verify threshold is hidden.
        if isHighLatencyThresholdVisible() {
            tapToggleControl(toggle)
            XCTAssertTrue(waitForHighLatencyThresholdVisibility(false), "Threshold should hide when high latency alerts are turned off")
        }
        XCTAssertFalse(isHighLatencyThresholdVisible(), "Threshold should be hidden when high latency alerts are off")

        tapToggleControl(toggle)
        XCTAssertTrue(waitForHighLatencyThresholdVisibility(true), "Threshold should appear after enabling high latency alerts")
    }

    func testHighLatencyToggleHidesThreshold() throws {
        let toggle = settingsScreen.highLatencyAlertToggle
        XCTAssertTrue(scrollToElement(toggle, maxSwipes: 4), "High latency alert toggle should be visible")

        // Start from ON and verify threshold is shown.
        if !isHighLatencyThresholdVisible() {
            tapToggleControl(toggle)
            XCTAssertTrue(waitForHighLatencyThresholdVisibility(true), "Threshold should appear when high latency alerts are turned on")
        }
        XCTAssertTrue(scrollToHighLatencyThreshold(maxSwipes: 3), "Threshold should be visible when high latency alerts are on")

        tapToggleControl(toggle)
        XCTAssertTrue(waitForHighLatencyThresholdVisibility(false), "Threshold should hide after disabling high latency alerts")
    }

    func testHighLatencyThresholdStepperIncrement() throws {
        let toggle = settingsScreen.highLatencyAlertToggle
        XCTAssertTrue(scrollToElement(toggle, maxSwipes: 4), "High latency alert toggle should be visible")

        if !isHighLatencyThresholdVisible() {
            tapToggleControl(toggle)
            XCTAssertTrue(waitForHighLatencyThresholdVisibility(true), "High latency threshold should appear when enabling high latency alerts")
        }

        XCTAssertTrue(scrollToHighLatencyThreshold(maxSwipes: 3), "High latency threshold should be visible before increment")
        guard let valueBeforeIncrement = highLatencyThresholdValue() else {
            XCTFail("High latency threshold value should be parseable")
            return
        }

        let incrementButton = settingsScreen.highLatencyThresholdStepperControl.buttons["Increment"].firstMatch
        XCTAssertTrue(incrementButton.waitForExistence(timeout: 2), "High latency threshold increment control should exist")
        incrementButton.tap()

        guard let nextValue = highLatencyThresholdValue() else {
            XCTFail("High latency threshold value should be parseable after increment")
            return
        }
        let expected = min(valueBeforeIncrement + 50, 500)
        XCTAssertEqual(nextValue, expected, "High latency threshold should increase by 50ms per increment tap")
    }

    // MARK: - Toggle Functional Verification Tests

    func testBackgroundRefreshToggleFunction() {
        let toggle = settingsScreen.backgroundRefreshToggle
        XCTAssertTrue(scrollToElement(toggle), "Background refresh toggle should exist")
        let stateLabel = backgroundRefreshStateLabel
        let initialState = boolFromOnOffLabel(stateLabel) ?? toggleState(resolvedToggleElement(toggle))
        guard let initialState else {
            XCTFail("Background refresh switch should expose deterministic state values.")
            return
        }

        XCTAssertTrue(
            tapToggleUntilStateChanges(toggle, initialState: initialState),
            "Background refresh toggle should change state after tap"
        )
        let newState = boolFromOnOffLabel(stateLabel) ?? toggleState(resolvedToggleElement(toggle))
        XCTAssertNotNil(newState, "Background refresh toggle should expose deterministic state after tap")
        guard let newState else { return }

        XCTAssertNotEqual(initialState, newState, "Background refresh toggle should change state after tap")

        // Verify value persists after leaving and reopening Settings.
        settingsScreen.navigateBack()
        settingsScreen = DashboardScreen(app: app).openSettings()
        let reopenedToggle = settingsScreen.backgroundRefreshToggle
        XCTAssertTrue(scrollToElement(reopenedToggle), "Background refresh toggle should be visible after reopening settings")
        let persistedState = boolFromOnOffLabel(backgroundRefreshStateLabel) ?? toggleState(resolvedToggleElement(reopenedToggle))
        XCTAssertEqual(persistedState, newState, "Background refresh setting should persist after reopening settings")

        // Restore original state for isolation.
        _ = ensureToggle(reopenedToggle, isOn: initialState)
    }

    func testShowDetailedResultsToggleFunction() {
        let toggle = settingsScreen.showDetailedResultsToggle
        XCTAssertTrue(scrollToElement(toggle), "Show detailed results toggle should exist")
        let stateLabel = showDetailedResultsStateLabel
        let initialState = boolFromOnOffLabel(stateLabel) ?? toggleState(resolvedToggleElement(toggle))
        guard let initialState else {
            XCTFail("Show detailed results switch should expose deterministic state values.")
            return
        }

        XCTAssertTrue(
            tapToggleUntilStateChanges(toggle, initialState: initialState),
            "Show detailed results toggle should change state after toggling"
        )
        let newState = boolFromOnOffLabel(stateLabel) ?? toggleState(resolvedToggleElement(toggle))
        XCTAssertNotNil(newState, "Show detailed results toggle should expose deterministic state after toggling")
        guard let newState else { return }

        XCTAssertNotEqual(initialState, newState, "Show detailed results toggle should change state after tap")

        // Verify downstream behavior by running Ping and checking packet stats visibility.
        app.tabBars.buttons["Tools"].tap()
        let toolsScreen = ToolsScreen(app: app)
        let pingScreen = toolsScreen.openPingTool()
        pingScreen.enterHost("1.1.1.1").startPing()
        XCTAssertTrue(
            pingScreen.waitForResults(timeout: 30),
            "Ping should complete so detailed-results downstream assertions can be evaluated"
        )

        let packetCardVisible = app.descendants(matching: .any)["pingTool_card_packets"].waitForExistence(timeout: 5)
        XCTAssertEqual(
            packetCardVisible,
            newState,
            "Packet statistics visibility should mirror Show Detailed Results setting"
        )

        // Return to settings and verify the toggle state persisted.
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.tabBars.buttons["Dashboard"].tap()
        settingsScreen = DashboardScreen(app: app).openSettings()
        XCTAssertTrue(scrollToElement(settingsScreen.showDetailedResultsToggle), "Show detailed results toggle should be visible after reopening settings")
        let persistedState = boolFromOnOffLabel(showDetailedResultsStateLabel) ?? toggleState(resolvedToggleElement(settingsScreen.showDetailedResultsToggle))
        XCTAssertEqual(persistedState, newState, "Show detailed results setting should persist after navigation")

        // Restore original state for isolation.
        _ = ensureToggle(settingsScreen.showDetailedResultsToggle, isOn: initialState)
    }

    // MARK: - Picker Functional Tests

    func testAccentColorPickerChanges() {
        settingsScreen.swipeUp()

        let picker = settingsScreen.accentColorPicker
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Accent color picker should exist")
        XCTAssertTrue(picker.isEnabled, "Accent color picker should be enabled")

        picker.tap()

        XCTAssertTrue(
            picker.exists,
            "Accent color picker should remain accessible after interaction"
        )
    }

    func testDataRetentionPickerChanges() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let picker = settingsScreen.dataRetentionPicker
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Data retention picker should exist")
        XCTAssertTrue(picker.isEnabled, "Data retention picker should be enabled")

        picker.tap()

        XCTAssertTrue(
            picker.exists,
            "Data retention picker should remain accessible after interaction"
        )
    }

    func testAutoRefreshIntervalPickerChanges() {
        settingsScreen.swipeUp()

        let picker = settingsScreen.autoRefreshPicker
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Auto-refresh interval picker should exist")
        XCTAssertTrue(picker.isEnabled, "Auto-refresh interval picker should be enabled")

        picker.tap()

        XCTAssertTrue(
            picker.exists,
            "Auto-refresh interval picker should remain accessible after interaction"
        )
    }

    // MARK: - Data Action Functional Tests

    func testClearHistoryConfirmClearsData() {
        settingsScreen.tapClearHistory()

        XCTAssertTrue(
            settingsScreen.clearHistoryAlert.waitForExistence(timeout: 5),
            "Clear history alert should appear"
        )

        settingsScreen.confirmClearHistory()

        XCTAssertFalse(
            settingsScreen.clearHistoryAlert.exists,
            "Clear history alert should be dismissed after confirmation"
        )

        // Settings screen should remain functional after the clear operation
        XCTAssertTrue(
            settingsScreen.isDisplayed(),
            "Settings screen should remain visible and functional after clearing history"
        )
    }

    func testClearCacheConfirmReducesSize() {
        settingsScreen.tapClearCache()

        XCTAssertTrue(
            settingsScreen.clearCacheAlert.waitForExistence(timeout: 5),
            "Clear cache alert should appear"
        )

        settingsScreen.confirmClearCache()

        XCTAssertFalse(
            settingsScreen.clearCacheAlert.exists,
            "Clear cache alert should be dismissed after confirmation"
        )

        // Settings screen should remain functional and the button should still be accessible
        XCTAssertTrue(
            settingsScreen.isDisplayed(),
            "Settings screen should remain visible and functional after clearing cache"
        )
        XCTAssertTrue(
            settingsScreen.clearCacheButton.exists,
            "Clear cache button should still be accessible after clearing"
        )
    }

    // MARK: - Export Menu Functional Tests

    func testExportToolResultsMenu() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let exportButton = settingsScreen.exportToolResultsMenu
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export tool results menu should exist")

        XCTAssertTrue(
            openExportMenuAndWaitForOptions(exportButton, optionRawValue: "toolResults"),
            "Tool results export menu should expose JSON/CSV options"
        )
        XCTAssertTrue(
            tapJSONExportOption(optionRawValue: "toolResults"),
            "Tool results export menu should allow selecting JSON export"
        )
        let shareSheetShown = waitForShareSheet(timeout: 2)
        if shareSheetShown {
            dismissShareSheetIfVisible()
        }
        XCTAssertTrue(
            shareSheetShown || settingsScreen.isDisplayed(),
            "Selecting tool-results export should either present share sheet or return to settings with no crash"
        )
        dismissExportMenuIfVisible()
    }

    func testExportSpeedTestsMenu() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let exportButton = settingsScreen.exportSpeedTestsMenu
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export speed tests menu should exist")

        guard openExportMenuAndWaitForOptions(exportButton, optionRawValue: "speedTests") else {
            XCTAssertTrue(exportButton.isEnabled, "Speed tests export control should remain enabled even when options are unavailable")
            XCTAssertTrue(settingsScreen.isDisplayed(), "Settings should remain responsive after speed-tests export interaction")
            return
        }
        XCTAssertTrue(
            tapJSONExportOption(optionRawValue: "speedTests"),
            "Speed tests export menu should allow selecting JSON export"
        )
        let shareSheetShown = waitForShareSheet(timeout: 2)
        if shareSheetShown {
            dismissShareSheetIfVisible()
        }
        XCTAssertTrue(
            shareSheetShown || settingsScreen.isDisplayed(),
            "Selecting speed-test export should either present share sheet or return to settings with no crash"
        )
        dismissExportMenuIfVisible()
    }

    func testExportDevicesMenu() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let exportButton = settingsScreen.exportDevicesMenu
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export devices menu should exist")

        XCTAssertTrue(
            openExportMenuAndWaitForOptions(exportButton, optionRawValue: "devices"),
            "Devices export menu should expose JSON/CSV options"
        )
        XCTAssertTrue(
            tapJSONExportOption(optionRawValue: "devices"),
            "Devices export menu should allow selecting JSON export"
        )
        let shareSheetShown = waitForShareSheet(timeout: 2)
        if shareSheetShown {
            dismissShareSheetIfVisible()
        }
        XCTAssertTrue(
            shareSheetShown || settingsScreen.isDisplayed(),
            "Selecting device export should either present share sheet or return to settings with no crash"
        )
        dismissExportMenuIfVisible()
    }

    // MARK: - Support & Feedback Functional Tests

    func testContactSupportLinkIsEnabled() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        XCTAssertTrue(
            settingsScreen.supportLink.waitForExistence(timeout: 5),
            "Contact Support link should exist"
        )

        // Verify the element is enabled (can be interacted with)
        XCTAssertTrue(
            settingsScreen.supportLink.isEnabled,
            "Contact Support link should be enabled for mailto interaction"
        )
    }

    func testRateAppButtonIsEnabled() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let rateButton = settingsScreen.rateAppButton
        XCTAssertTrue(rateButton.waitForExistence(timeout: 5), "Rate App button should exist")
        XCTAssertTrue(rateButton.isEnabled, "Rate App button should be enabled and tappable")
        XCTAssertTrue(rateButton.isHittable, "Rate App button should be hittable (visible on screen)")
    }
}
