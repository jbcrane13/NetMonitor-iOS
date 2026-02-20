import XCTest

/// Settings screen page object
final class SettingsScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_settings"]
    }

    // MARK: - Network Tools Settings
    var pingCountStepper: XCUIElement {
        app.descendants(matching: .any)["settings_stepper_pingCount"]
    }

    var pingTimeoutStepper: XCUIElement {
        app.descendants(matching: .any)["settings_stepper_pingTimeout"]
    }

    var portScanTimeoutStepper: XCUIElement {
        app.descendants(matching: .any)["settings_stepper_portScanTimeout"]
    }

    // Fallback text references for settings elements
    var pingCountText: XCUIElement { app.staticTexts["Ping Count"] }
    var pingTimeoutText: XCUIElement { app.staticTexts["Ping Timeout"] }
    var portScanTimeoutText: XCUIElement { app.staticTexts["Port Scan Timeout"] }
    var autoRefreshText: XCUIElement { app.staticTexts["Auto-Refresh Interval"] }
    var themeText: XCUIElement { app.staticTexts["Theme"] }
    var accentColorText: XCUIElement { app.staticTexts["Accent Color"] }
    var dataRetentionText: XCUIElement { app.staticTexts["Data Retention"] }
    var appVersionText: XCUIElement { app.staticTexts["App Version"] }
    var buildNumberText: XCUIElement { app.staticTexts["Build Number"] }
    var iosVersionText: XCUIElement { app.staticTexts["iOS Version"] }
    
    var dnsServerTextField: XCUIElement {
        app.descendants(matching: .any)["settings_textfield_dnsServer"]
    }
    
    // MARK: - Monitoring Settings
    var autoRefreshPicker: XCUIElement {
        app.descendants(matching: .any)["settings_picker_autoRefreshInterval"]
    }

    var backgroundRefreshToggle: XCUIElement {
        app.switches["settings_toggle_backgroundRefresh"]
    }

    // MARK: - Notification Settings
    var targetDownAlertToggle: XCUIElement {
        app.switches["settings_toggle_targetDownAlert"]
    }

    var highLatencyThresholdStepper: XCUIElement {
        app.descendants(matching: .any)["settings_stepper_highLatencyThreshold"]
    }

    var highLatencyAlertToggle: XCUIElement {
        app.switches["settings_toggle_highLatencyAlert"]
    }

    var newDeviceAlertToggle: XCUIElement {
        app.switches["settings_toggle_newDeviceAlert"]
    }

    // MARK: - Appearance Settings
    var themePicker: XCUIElement {
        app.descendants(matching: .any)["settings_picker_theme"]
    }

    var accentColorPicker: XCUIElement {
        app.descendants(matching: .any)["settings_picker_accentColor"]
    }

    // MARK: - Data & Privacy
    var dataRetentionPicker: XCUIElement {
        app.descendants(matching: .any)["settings_picker_dataRetention"]
    }
    
    var showDetailedResultsToggle: XCUIElement {
        app.switches["settings_toggle_showDetailedResults"]
    }
    
    var clearHistoryButton: XCUIElement {
        app.buttons["settings_button_clearHistory"]
    }
    
    var clearCacheButton: XCUIElement {
        app.buttons["settings_button_clearCache"]
    }
    
    // MARK: - About
    var appVersionRow: XCUIElement {
        app.descendants(matching: .any)["settings_row_appVersion"]
    }

    var buildNumberRow: XCUIElement {
        app.descendants(matching: .any)["settings_row_buildNumber"]
    }

    var iosVersionRow: XCUIElement {
        app.descendants(matching: .any)["settings_row_iosVersion"]
    }
    
    var acknowledgementsLink: XCUIElement {
        app.buttons["settings_link_acknowledgements"]
    }
    
    var supportLink: XCUIElement {
        app.descendants(matching: .any)["settings_link_support"]
    }

    var supportLinkAsButton: XCUIElement {
        app.descendants(matching: .any)["settings_link_support"]
    }

    // Fallback text reference for support link
    var supportLinkText: XCUIElement { app.staticTexts["Contact Support"] }
    
    var rateAppButton: XCUIElement {
        app.buttons["settings_button_rateApp"]
    }
    
    // MARK: - Export
    var exportToolResultsMenu: XCUIElement {
        app.buttons["settings_export_toolResults"]
    }
    
    var exportSpeedTestsMenu: XCUIElement {
        app.buttons["settings_export_speedTests"]
    }
    
    var exportDevicesMenu: XCUIElement {
        app.buttons["settings_export_devices"]
    }
    
    // MARK: - Alerts
    var clearHistoryAlert: XCUIElement {
        app.alerts["Clear History"]
    }
    
    var clearCacheAlert: XCUIElement {
        app.alerts["Clear All Cached Data"]
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        // Check for the navigation bar title instead of screen container for more reliable detection
        // Navigation bars become available faster than otherElements during navigation
        app.navigationBars["Settings"].waitForExistence(timeout: timeout)
    }
    
    // MARK: - Actions
    @discardableResult
    func tapClearHistory() -> Self {
        // Scroll to find the button if needed - Data & Privacy is near the bottom
        swipeUp()
        swipeUp()
        if !clearHistoryButton.waitForExistence(timeout: 3) {
            swipeUp()
        }
        tapIfExists(clearHistoryButton)
        return self
    }

    @discardableResult
    func tapClearCache() -> Self {
        // Scroll to find the button if needed - Clear Cache is near the bottom
        swipeUp()
        swipeUp()
        if !clearCacheButton.waitForExistence(timeout: 3) {
            swipeUp()
        }
        tapIfExists(clearCacheButton)
        return self
    }
    
    @discardableResult
    func confirmClearHistory() -> Self {
        if clearHistoryAlert.waitForExistence(timeout: timeout) {
            clearHistoryAlert.buttons["Clear"].tap()
        }
        return self
    }
    
    @discardableResult
    func cancelClearHistory() -> Self {
        if clearHistoryAlert.waitForExistence(timeout: timeout) {
            clearHistoryAlert.buttons["Cancel"].tap()
        }
        return self
    }
    
    @discardableResult
    func confirmClearCache() -> Self {
        if clearCacheAlert.waitForExistence(timeout: timeout) {
            clearCacheAlert.buttons["Clear All"].tap()
        }
        return self
    }
    
    @discardableResult
    func cancelClearCache() -> Self {
        if clearCacheAlert.waitForExistence(timeout: timeout) {
            clearCacheAlert.buttons["Cancel"].tap()
        }
        return self
    }
    
    @discardableResult
    func openAcknowledgements() -> Self {
        swipeUp()
        tapIfExists(acknowledgementsLink)
        return self
    }
    
    /// Navigate back to Dashboard
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
