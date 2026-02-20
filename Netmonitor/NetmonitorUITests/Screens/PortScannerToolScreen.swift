import XCTest

/// Port Scanner Tool screen page object
final class PortScannerToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_portScannerTool"]
    }

    // MARK: - Input Elements
    var hostInput: XCUIElement {
        app.textFields["portScanner_input_host"]
    }

    var portRangePicker: XCUIElement {
        app.buttons["portScanner_picker_range"]
    }

    var startPortInput: XCUIElement {
        app.textFields["portScanner_input_startPort"]
    }

    var endPortInput: XCUIElement {
        app.textFields["portScanner_input_endPort"]
    }

    // MARK: - Control Buttons
    var runButton: XCUIElement {
        app.buttons["portScanner_button_run"]
    }

    var clearButton: XCUIElement {
        app.buttons["portScanner_button_clear"]
    }

    // MARK: - Progress
    var progressIndicator: XCUIElement {
        app.descendants(matching: .any)["portScanner_progress"]
    }

    // MARK: - Results
    var resultsSection: XCUIElement {
        app.descendants(matching: .any)["portScanner_section_results"]
    }

    var resultRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'portScanner_result_'")
        )
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        // Check for run button instead of screen container for more reliable detection
        // Buttons become available faster than otherElements during navigation
        runButton.waitForExistence(timeout: timeout)
    }
    
    // MARK: - Actions
    @discardableResult
    func enterHost(_ host: String) -> Self {
        if hostInput.waitForExistence(timeout: timeout) {
            hostInput.tap()
            hostInput.typeText(host)
        }
        return self
    }
    
    @discardableResult
    func selectPortRange(_ range: String) -> Self {
        if portRangePicker.waitForExistence(timeout: timeout) {
            portRangePicker.tap()
            app.buttons[range].tap()
        }
        return self
    }
    
    @discardableResult
    func startScan() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func stopScan() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func clearResults() -> Self {
        tapIfExists(clearButton)
        return self
    }
    
    func waitForResults(timeout: TimeInterval = 60) -> Bool {
        resultsSection.waitForExistence(timeout: timeout)
    }
    
    func isScanning() -> Bool {
        progressIndicator.exists
    }

    func waitForRunningState(timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Stop Scan'")
        return app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    func waitForIdleState(timeout: TimeInterval = 15) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Start Scan'")
        return app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }
    
    /// Get count of port result rows
    func getPortResultCount() -> Int {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'portScanner_result_'")).count
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
