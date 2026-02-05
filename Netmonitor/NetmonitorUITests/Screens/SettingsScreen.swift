import XCTest

/// Settings screen page object
final class SettingsScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_settings"]
    }
    
    // MARK: - Network Tools Settings
    var pingCountStepper: XCUIElement {
        app.otherElements["settings_stepper_pingCount"]
    }
    
    var pingTimeoutStepper: XCUIElement {
        app.otherElements["settings_stepper_pingTimeout"]
    }
    
    var portScanTimeoutStepper: XCUIElement {
        app.otherElements["settings_stepper_portScanTimeout"]
    }
    
    var dnsServerTextField: XCUIElement {
        app.textFields["settings_textfield_dnsServer"]
    }
    
    // MARK: - Monitoring Settings
    var autoRefreshPicker: XCUIElement {
        app.otherElements["settings_picker_autoRefreshInterval"]
    }
    
    var backgroundRefreshToggle: XCUIElement {
        app.switches["settings_toggle_backgroundRefresh"]
    }
    
    // MARK: - Notification Settings
    var targetDownAlertToggle: XCUIElement {
        app.switches["settings_toggle_targetDownAlert"]
    }
    
    var highLatencyThresholdStepper: XCUIElement {
        app.otherElements["settings_stepper_highLatencyThreshold"]
    }
    
    var newDeviceAlertToggle: XCUIElement {
        app.switches["settings_toggle_newDeviceAlert"]
    }
    
    // MARK: - Appearance Settings
    var themePicker: XCUIElement {
        app.otherElements["settings_picker_theme"]
    }
    
    var accentColorPicker: XCUIElement {
        app.otherElements["settings_picker_accentColor"]
    }
    
    // MARK: - Data & Privacy
    var dataRetentionPicker: XCUIElement {
        app.otherElements["settings_picker_dataRetention"]
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
        app.otherElements["settings_row_appVersion"]
    }
    
    var buildNumberRow: XCUIElement {
        app.otherElements["settings_row_buildNumber"]
    }
    
    var iosVersionRow: XCUIElement {
        app.otherElements["settings_row_iosVersion"]
    }
    
    var acknowledgementsLink: XCUIElement {
        app.buttons["settings_link_acknowledgements"]
    }
    
    var supportLink: XCUIElement {
        app.links["settings_link_support"]
    }
    
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
        waitForElement(screen)
    }
    
    // MARK: - Actions
    @discardableResult
    func tapClearHistory() -> Self {
        // Scroll to find the button if needed
        swipeUp()
        tapIfExists(clearHistoryButton)
        return self
    }
    
    @discardableResult
    func tapClearCache() -> Self {
        swipeUp()
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
