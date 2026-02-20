import XCTest

/// Bonjour Discovery Tool screen page object
final class BonjourToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_bonjourTool"]
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
        app.descendants(matching: .any)["bonjour_section_services"]
    }

    var emptyStateNoServices: XCUIElement {
        app.descendants(matching: .any)["bonjour_emptystate_noservices"]
    }

    var serviceRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'bonjour_service_'")
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
    func startDiscovery() -> Self {
        if runButton.waitForExistence(timeout: timeout) {
            let label = runButton.label.lowercased()
            if label.contains("start") || !label.contains("stop") {
                runButton.tap()
            }
        }
        return self
    }
    
    @discardableResult
    func stopDiscovery() -> Self {
        if runButton.waitForExistence(timeout: timeout) {
            let label = runButton.label.lowercased()
            if label.contains("stop") {
                runButton.tap()
            }
        }
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

    func waitForDiscoveringState(timeout: TimeInterval = 8) -> Bool {
        let stopLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Stop Discovery'")).firstMatch
        let discoveringText = app.staticTexts["Discovering services..."]
        return stopLabel.waitForExistence(timeout: timeout) || discoveringText.waitForExistence(timeout: timeout)
    }

    func waitForIdleState(timeout: TimeInterval = 8) -> Bool {
        let startLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Start Discovery'")).firstMatch
        return startLabel.waitForExistence(timeout: timeout)
    }

    func waitForCompletedOutcome(timeout: TimeInterval = 25) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if servicesSection.exists || emptyStateNoServices.exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return servicesSection.exists || emptyStateNoServices.exists
    }
    
    func hasEmptyState() -> Bool {
        emptyStateNoServices.exists
    }
    
    /// Get count of discovered services
    func getServiceCount() -> Int {
        serviceRows.count
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
