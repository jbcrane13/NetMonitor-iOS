import XCTest

/// Traceroute Tool screen page object
final class TracerouteToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_tracerouteTool"]
    }
    
    // MARK: - Input Elements
    var hostInput: XCUIElement {
        app.textFields["tracerouteTool_input_host"]
    }
    
    var maxHopsPicker: XCUIElement {
        app.buttons["tracerouteTool_picker_maxHops"]
    }
    
    // MARK: - Control Buttons
    var runButton: XCUIElement {
        app.buttons["tracerouteTool_button_run"]
    }
    
    var clearButton: XCUIElement {
        app.buttons["tracerouteTool_button_clear"]
    }
    
    // MARK: - Results
    var hopsSection: XCUIElement {
        app.otherElements["tracerouteTool_section_hops"]
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        waitForElement(screen)
    }
    
    // MARK: - Actions
    @discardableResult
    func enterHost(_ host: String) -> Self {
        if hostInput.waitForExistence(timeout: timeout) {
            hostInput.tap()
            hostInput.typeText(host)
        }
        return self
    }
    
    @discardableResult
    func startTrace() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func stopTrace() -> Self {
        tapIfExists(runButton)
        return self
    }
    
    @discardableResult
    func clearResults() -> Self {
        tapIfExists(clearButton)
        return self
    }
    
    func waitForHops(timeout: TimeInterval = 60) -> Bool {
        hopsSection.waitForExistence(timeout: timeout)
    }
    
    /// Get count of hop rows
    func getHopCount() -> Int {
        app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'tracerouteTool_hop_'")).count
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
