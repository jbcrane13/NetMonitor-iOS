import XCTest

/// Speed Test Tool screen page object
final class SpeedTestToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_speedTestTool"]
    }

    // MARK: - Elements
    var gauge: XCUIElement {
        app.descendants(matching: .any)["speedTest_gauge"]
    }

    // MARK: - Control Buttons
    var runButton: XCUIElement {
        app.buttons["speedTest_button_run"]
    }

    // MARK: - Results
    var resultsSection: XCUIElement {
        app.descendants(matching: .any)["speedTest_results"]
    }

    var historySection: XCUIElement {
        app.descendants(matching: .any)["speedTest_section_history"]
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        // Check for run button instead of screen container for more reliable detection
        // Buttons become available faster than otherElements during navigation
        runButton.waitForExistence(timeout: timeout)
    }
    
    // MARK: - Actions
    @discardableResult
    func startTest() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func stopTest() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    func waitForResults(timeout: TimeInterval = 120) -> Bool {
        resultsSection.waitForExistence(timeout: timeout)
    }
    
    func hasHistory() -> Bool {
        historySection.exists
    }
    
    func verifyGaugePresent() -> Bool {
        // The gauge ZStack may not be found as otherElements in XCUITest.
        // Fall back to checking for known gauge content like "Mbps" text or "0.0" text.
        waitForElement(gauge) ||
        app.staticTexts["Mbps"].waitForExistence(timeout: timeout) ||
        app.staticTexts["0.0"].waitForExistence(timeout: timeout)
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
