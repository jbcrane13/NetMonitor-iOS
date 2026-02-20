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

    var durationSegment5s: XCUIElement {
        app.buttons["5s"]
    }

    var durationSegment10s: XCUIElement {
        app.buttons["10s"]
    }

    var durationSegment30s: XCUIElement {
        app.buttons["30s"]
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
        waitForElement(gauge)
    }

    func waitForRunningState(timeout: TimeInterval = 8) -> Bool {
        let stopLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Stop Test'")).firstMatch
        return stopLabel.waitForExistence(timeout: timeout)
    }

    func waitForIdleState(timeout: TimeInterval = 8) -> Bool {
        let startLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start Test'")).firstMatch
        return startLabel.waitForExistence(timeout: timeout)
    }

    func hasError() -> Bool {
        app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'failed'")
        ).count > 0
    }

    func waitForCompletedOutcome(timeout: TimeInterval = 95) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if resultsSection.exists || hasError() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return resultsSection.exists || hasError()
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
