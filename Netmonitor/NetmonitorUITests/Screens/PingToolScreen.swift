import XCTest

/// Ping Tool screen page object
final class PingToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_pingTool"]
    }

    // MARK: - Input Elements
    var hostInput: XCUIElement {
        app.textFields["pingTool_input_host"]
    }

    var countPicker: XCUIElement {
        app.buttons["pingTool_picker_count"]
    }

    // MARK: - Control Buttons
    var runButton: XCUIElement {
        app.buttons["pingTool_button_run"]
    }

    var clearButton: XCUIElement {
        app.buttons["pingTool_button_clear"]
    }

    // MARK: - Results
    var resultsSection: XCUIElement {
        app.descendants(matching: .any)["pingTool_section_results"]
    }

    var statisticsCard: XCUIElement {
        app.descendants(matching: .any)["pingTool_card_statistics"]
    }

    var packetsCard: XCUIElement {
        app.descendants(matching: .any)["pingTool_card_packets"]
    }

    var resultRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'pingTool_result_'")
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
    func startPing() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func stopPing() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func clearResults() -> Self {
        tapIfExists(clearButton)
        return self
    }
    
    func waitForResults(timeout: TimeInterval = 30) -> Bool {
        resultsSection.waitForExistence(timeout: timeout)
    }
    
    func waitForStatistics(timeout: TimeInterval = 30) -> Bool {
        statisticsCard.waitForExistence(timeout: timeout)
    }

    func waitForRunningState(timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Stop Ping'")
        return app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    func waitForIdleState(timeout: TimeInterval = 8) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS[c] 'Start Ping'")
        return app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }
    
    /// Get count of result rows
    func getResultCount() -> Int {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'pingTool_result_'")).count
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
