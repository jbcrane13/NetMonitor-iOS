import XCTest

/// WHOIS Tool screen page object
final class WHOISToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_whoisTool"]
    }

    // MARK: - Input Elements
    var domainInput: XCUIElement {
        app.textFields["whois_input_domain"]
    }

    // MARK: - Control Buttons
    var runButton: XCUIElement {
        app.buttons["whois_button_run"]
    }

    var clearButton: XCUIElement {
        app.buttons["whois_button_clear"]
    }

    // MARK: - Results
    var domainInfoCard: XCUIElement {
        app.descendants(matching: .any)["whois_domainInfo"]
    }

    var datesCard: XCUIElement {
        app.descendants(matching: .any)["whois_dates"]
    }

    var nameServersCard: XCUIElement {
        app.descendants(matching: .any)["whois_nameServers"]
    }

    var errorView: XCUIElement {
        app.descendants(matching: .any)["whois_error"]
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
    func startLookup() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func clearResults() -> Self {
        tapIfExists(clearButton)
        return self
    }
    
    func waitForDomainInfo(timeout: TimeInterval = 15) -> Bool {
        domainInfoCard.waitForExistence(timeout: timeout)
    }

    func waitForDates(timeout: TimeInterval = 15) -> Bool {
        datesCard.waitForExistence(timeout: timeout)
    }

    func waitForNameServers(timeout: TimeInterval = 15) -> Bool {
        nameServersCard.waitForExistence(timeout: timeout)
    }

    func hasError() -> Bool {
        errorView.exists
    }

    func waitForCompletedOutcome(timeout: TimeInterval = 35) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if domainInfoCard.exists || errorView.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return domainInfoCard.exists || errorView.exists
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
