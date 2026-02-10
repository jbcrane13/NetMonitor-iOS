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

    // Fallback text references
    var domainDatesText: XCUIElement { app.staticTexts["Domain Dates"] }
    var nameServersText: XCUIElement { app.staticTexts["Name Servers"] }
    
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
        // Try otherElements first, fall back to checking for the "Domain" label text
        domainInfoCard.waitForExistence(timeout: timeout) ||
        app.staticTexts["Registrar"].waitForExistence(timeout: 2)
    }

    func waitForDates(timeout: TimeInterval = 15) -> Bool {
        datesCard.waitForExistence(timeout: timeout) ||
        domainDatesText.waitForExistence(timeout: 2)
    }

    func waitForNameServers(timeout: TimeInterval = 15) -> Bool {
        nameServersCard.waitForExistence(timeout: timeout) ||
        nameServersText.waitForExistence(timeout: 2)
    }

    func hasError() -> Bool {
        errorView.exists ||
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'failed' OR label CONTAINS[c] 'error' OR label CONTAINS[c] 'timed out' OR label CONTAINS[c] 'could not'")).count > 0 ||
        app.images["exclamationmark.triangle"].exists ||
        app.images["exclamationmark.triangle.fill"].exists
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
