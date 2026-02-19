import XCTest

/// SetTarget sheet page object
final class SetTargetScreen: BaseScreen {

    // MARK: - Quick Action (on Tools Screen)

    var setTargetQuickActionButton: XCUIElement {
        app.buttons["quickAction_set_target"]
    }

    // MARK: - Sheet Navigation Bar

    var sheetNavigationBar: XCUIElement {
        app.navigationBars["Set Target"]
    }

    // MARK: - Input Elements

    var addressInput: XCUIElement {
        app.textFields["setTarget_input_address"]
    }

    /// Set button — only visible when address field is non-empty
    var setButton: XCUIElement {
        app.buttons["setTarget_button_set"]
    }

    /// Clear button — only visible when there is an active target
    var clearButton: XCUIElement {
        app.buttons["setTarget_button_clear"]
    }

    var cancelButton: XCUIElement {
        app.buttons["Cancel"]
    }

    // MARK: - Section Headers

    var activeTargetHeader: XCUIElement {
        app.staticTexts["Active Target"]
    }

    var savedTargetsHeader: XCUIElement {
        app.staticTexts["Saved Targets"]
    }

    // MARK: - Verification

    func isSheetDisplayed() -> Bool {
        sheetNavigationBar.waitForExistence(timeout: timeout)
    }

    func isSheetDismissed() -> Bool {
        !sheetNavigationBar.waitForExistence(timeout: timeout)
    }

    // MARK: - Navigation

    @discardableResult
    func openSheet() -> Self {
        tapIfExists(setTargetQuickActionButton)
        _ = waitForElement(sheetNavigationBar)
        return self
    }

    // MARK: - Actions

    @discardableResult
    func enterAddress(_ address: String) -> Self {
        typeText(addressInput, text: address)
        return self
    }

    @discardableResult
    func tapSet() -> Self {
        tapIfExists(setButton)
        return self
    }

    @discardableResult
    func tapClear() -> Self {
        tapIfExists(clearButton)
        return self
    }

    @discardableResult
    func tapCancel() -> Self {
        tapIfExists(cancelButton)
        return self
    }

    /// Returns the saved target row for the given address.
    /// Matches the accessibility ID format: setTarget_saved_{address with dots replaced by underscores}
    func savedTargetRow(for target: String) -> XCUIElement {
        let sanitized = target.replacingOccurrences(of: ".", with: "_")
        return app.buttons["setTarget_saved_\(sanitized)"]
    }
}
