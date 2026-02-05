import XCTest

/// Speed Test Tool screen page object
final class SpeedTestToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_speedTestTool"]
    }
    
    // MARK: - Elements
    var gauge: XCUIElement {
        app.otherElements["speedTest_gauge"]
    }
    
    // MARK: - Control Buttons
    var runButton: XCUIElement {
        app.buttons["speedTest_button_run"]
    }
    
    // MARK: - Results
    var resultsSection: XCUIElement {
        app.otherElements["speedTest_results"]
    }
    
    var historySection: XCUIElement {
        app.otherElements["speedTest_section_history"]
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        waitForElement(screen)
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
        waitForElement(gauge)
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
