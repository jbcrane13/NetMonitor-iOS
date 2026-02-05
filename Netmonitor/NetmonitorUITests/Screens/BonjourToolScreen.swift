import XCTest

/// Bonjour Discovery Tool screen page object
final class BonjourToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_bonjourTool"]
    }
    
    // MARK: - Control Buttons
    var runButton: XCUIElement {
        app.buttons["bonjour_button_run"]
    }
    
    var clearButton: XCUIElement {
        app.buttons["bonjour_button_clear"]
    }
    
    // MARK: - Results
    var servicesSection: XCUIElement {
        app.otherElements["bonjour_section_services"]
    }
    
    var emptyStateNoServices: XCUIElement {
        app.otherElements["bonjour_emptystate_noservices"]
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        waitForElement(screen)
    }
    
    // MARK: - Actions
    @discardableResult
    func startDiscovery() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func stopDiscovery() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func clearResults() -> Self {
        tapIfExists(clearButton)
        return self
    }
    
    func waitForServices(timeout: TimeInterval = 15) -> Bool {
        servicesSection.waitForExistence(timeout: timeout)
    }
    
    func hasEmptyState() -> Bool {
        emptyStateNoServices.exists
    }
    
    /// Get count of discovered services
    func getServiceCount() -> Int {
        app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'bonjour_service_'")).count
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
