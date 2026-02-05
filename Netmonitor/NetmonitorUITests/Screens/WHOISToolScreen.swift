import XCTest

/// WHOIS Tool screen page object
final class WHOISToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_whoisTool"]
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
        app.otherElements["whois_domainInfo"]
    }
    
    var datesCard: XCUIElement {
        app.otherElements["whois_dates"]
    }
    
    var nameServersCard: XCUIElement {
        app.otherElements["whois_nameServers"]
    }
    
    var errorView: XCUIElement {
        app.otherElements["whois_error"]
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        waitForElement(screen)
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
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
