import XCTest

/// DNS Lookup Tool screen page object
final class DNSLookupToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_dnsLookupTool"]
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
        app.otherElements["dnsLookup_queryInfo"]
    }
    
    var recordsCard: XCUIElement {
        app.otherElements["dnsLookup_records"]
    }
    
    var errorView: XCUIElement {
        app.otherElements["dnsLookup_error"]
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
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
