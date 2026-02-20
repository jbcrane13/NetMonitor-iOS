import XCTest

/// Network Map screen page object
final class NetworkMapScreen: BaseScreen {

    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_networkMap"]
    }

    // MARK: - Elements
    var summaryCard: XCUIElement {
        app.descendants(matching: .any)["networkMap_summary"]
    }

    var sortPicker: XCUIElement {
        app.descendants(matching: .any)["networkMap_picker_sort"]
    }

    var emptyStateLabel: XCUIElement {
        app.descendants(matching: .any)["networkMap_label_empty"]
    }

    var scanButton: XCUIElement {
        app.buttons["networkMap_button_scan"]
    }

    var deviceRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'networkMap_row_'")
        )
    }

    // MARK: - Navigation
    @discardableResult
    func navigateToNetworkMap() -> Self {
        navigateToTab("Map")
        // Wait for a reliable toolbar control
        _ = waitForElement(scanButton)
        return self
    }

    // MARK: - Actions
    @discardableResult
    func startScan() -> Self {
        tapIfExists(scanButton)
        return self
    }

    @discardableResult
    func tapFirstDeviceRow() -> Bool {
        let firstRow = deviceRows.element(boundBy: 0)
        guard firstRow.waitForExistence(timeout: timeout) else { return false }
        firstRow.tap()
        return true
    }

    // MARK: - Verification
    func isDisplayed() -> Bool {
        // Toolbar controls are generally more stable than list containers during load.
        waitForElement(scanButton)
    }

    func hasAnyDeviceRow(timeout: TimeInterval = 8) -> Bool {
        deviceRows.element(boundBy: 0).waitForExistence(timeout: timeout)
    }

    func verifyCoreUIVisible() -> Bool {
        waitForElement(summaryCard) && waitForElement(sortPicker) && waitForElement(scanButton)
    }

    func isShowingScanProgress() -> Bool {
        let hasSpinner = app.activityIndicators.count > 0
        let hasScanningText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'scanning' OR label CONTAINS[c] 'discovering'")
        ).count > 0
        return hasSpinner || hasScanningText
    }

    /// Get count of discovered device rows.
    func getDeviceRowCount() -> Int {
        deviceRows.count
    }
}
