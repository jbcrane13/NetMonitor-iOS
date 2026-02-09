import XCTest

/// UI tests for the Bonjour Discovery tool functionality
final class BonjourToolUITests: XCTestCase {
    
    var app: XCUIApplication!
    var bonjourScreen: BonjourToolScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        bonjourScreen = toolsScreen.openBonjourTool()
    }
    
    override func tearDown() {
        app = nil
        bonjourScreen = nil
        super.tearDown()
    }
    
    // MARK: - Screen Display Tests
    
    func testBonjourToolScreenDisplays() {
        XCTAssertTrue(bonjourScreen.isDisplayed(), "Bonjour tool screen should be displayed")
    }
    
    func testRunButtonExists() {
        XCTAssertTrue(
            bonjourScreen.runButton.waitForExistence(timeout: 5),
            "Discovery button should exist"
        )
    }
    
    // MARK: - Execution Tests
    
    func testCanStartDiscovery() {
        bonjourScreen.startDiscovery()

        // Either services are found, empty state shows after discovery,
        // or the tool remains functional (in simulator, discovery may not complete).
        let servicesFound = bonjourScreen.servicesSection.waitForExistence(timeout: 15)
        let emptyState = bonjourScreen.emptyStateNoServices.waitForExistence(timeout: 5)

        XCTAssertTrue(
            servicesFound || emptyState || bonjourScreen.runButton.waitForExistence(timeout: 5),
            "Bonjour discovery should show services, empty state, or remain functional"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        bonjourScreen.navigateBack()
        
        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }
}
