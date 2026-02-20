import XCTest

/// DNS Lookup Tool screen page object
final class DNSLookupToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_dnsLookupTool"]
    }

    // MARK: - Input Elements
    var domainInput: XCUIElement {
        app.textFields["dnsLookup_input_domain"]
    }

    var recordTypePicker: XCUIElement {
        app.buttons["dnsLookup_picker_type"]
    }

    // MARK: - Control Buttons
    var runButton: XCUIElement {
        app.buttons["dnsLookup_button_run"]
    }

    var clearButton: XCUIElement {
        app.buttons["dnsLookup_button_clear"]
    }

    // MARK: - Results
    var queryInfoCard: XCUIElement {
        app.descendants(matching: .any)["dnsLookup_queryInfo"]
    }

    var recordsCard: XCUIElement {
        app.descendants(matching: .any)["dnsLookup_records"]
    }

    var errorView: XCUIElement {
        app.descendants(matching: .any)["dnsLookup_error"]
    }

    var recordRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'dnsLookup_record_'")
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
    func enterDomain(_ domain: String) -> Self {
        if domainInput.waitForExistence(timeout: timeout) {
            domainInput.tap()
            domainInput.typeText(domain)
        }
        return self
    }
    
    @discardableResult
    func selectRecordType(_ type: String) -> Self {
        if recordTypePicker.waitForExistence(timeout: timeout) {
            recordTypePicker.tap()
            app.buttons[type].tap()
        }
        return self
    }
    
    @discardableResult
    func startLookup() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func clearResults() -> Self {
        tapIfExists(clearButton)
        return self
    }
    
    func waitForQueryInfo(timeout: TimeInterval = 15) -> Bool {
        queryInfoCard.waitForExistence(timeout: timeout)
    }
    
    func waitForRecords(timeout: TimeInterval = 15) -> Bool {
        recordsCard.waitForExistence(timeout: timeout)
    }
    
    func hasError() -> Bool {
        errorView.exists
    }

    func waitForCompletedOutcome(timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if queryInfoCard.exists || errorView.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return queryInfoCard.exists || errorView.exists
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
