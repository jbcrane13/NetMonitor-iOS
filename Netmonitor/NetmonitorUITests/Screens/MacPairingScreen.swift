import XCTest

/// Mac Pairing sheet page object
final class MacPairingScreen: BaseScreen {

    // MARK: - Screen Identifier

    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_macPairing"]
    }

    var navigationBar: XCUIElement {
        app.navigationBars["Connect to Mac"]
    }

    // MARK: - Settings Entry Points

    /// "Connect to Mac" button — visible when not connected
    var connectMacButton: XCUIElement {
        app.buttons["settings_button_connectMac"]
    }

    /// "Disconnect" button — visible only when connected
    var disconnectButton: XCUIElement {
        app.buttons["settings_button_disconnect"]
    }

    var connectionStatusRow: XCUIElement {
        app.descendants(matching: .any)["settings_row_connectionStatus"]
    }

    // MARK: - Discovered Macs Section

    var searchingIndicator: XCUIElement {
        app.descendants(matching: .any)["pairing_searching"]
    }

    var emptyState: XCUIElement {
        app.descendants(matching: .any)["pairing_empty"]
    }

    var discoveredMacsHeader: XCUIElement {
        app.staticTexts["Discovered Macs"]
    }

    // MARK: - Manual Connection Section

    var manualConnectionHeader: XCUIElement {
        app.staticTexts["Manual Connection"]
    }

    /// Toggle button to expand/collapse manual entry fields
    var manualToggle: XCUIElement {
        app.buttons["pairing_manual_toggle"]
    }

    var manualHostField: XCUIElement {
        app.textFields["pairing_manual_host"]
    }

    var manualPortField: XCUIElement {
        app.textFields["pairing_manual_port"]
    }

    var manualConnectButton: XCUIElement {
        app.buttons["pairing_manual_connect"]
    }

    // MARK: - Toolbar

    var cancelButton: XCUIElement {
        app.buttons["pairing_cancel"]
    }

    // MARK: - Connection Status Section

    var statusSectionHeader: XCUIElement {
        app.staticTexts["Status"]
    }

    /// Done button — only visible when connectionState.isConnected == true
    var doneButton: XCUIElement {
        app.buttons["pairing_done"]
    }

    // MARK: - Verification

    func isSheetDisplayed() -> Bool {
        navigationBar.waitForExistence(timeout: timeout)
    }

    func isSheetDismissed() -> Bool {
        !navigationBar.waitForExistence(timeout: timeout)
    }

    func isManualEntryExpanded() -> Bool {
        manualHostField.waitForExistence(timeout: 3)
    }

    // MARK: - Navigation

    @discardableResult
    func openSheet() -> Self {
        tapIfExists(connectMacButton)
        _ = waitForElement(navigationBar)
        return self
    }

    // MARK: - Actions

    @discardableResult
    func expandManualEntry() -> Self {
        tapIfExists(manualToggle)
        return self
    }

    @discardableResult
    func enterManualHost(_ host: String) -> Self {
        typeText(manualHostField, text: host)
        return self
    }

    @discardableResult
    func clearAndEnterManualPort(_ port: String) -> Self {
        if manualPortField.waitForExistence(timeout: timeout) {
            manualPortField.tap()
            manualPortField.press(forDuration: 1.0)
            if app.menuItems["Select All"].waitForExistence(timeout: 2) {
                app.menuItems["Select All"].tap()
            }
            manualPortField.typeText(port)
        }
        return self
    }

    @discardableResult
    func tapConnect() -> Self {
        tapIfExists(manualConnectButton)
        return self
    }

    @discardableResult
    func tapCancel() -> Self {
        tapIfExists(cancelButton)
        return self
    }

    @discardableResult
    func tapDone() -> Self {
        tapIfExists(doneButton)
        return self
    }
}
