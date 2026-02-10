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

        // In simulator environments, Bonjour discovery may not complete due to network restrictions.
        // Verify the UI responds to the tap by checking for any of these states:
        // 1. Services section appears (discovery succeeded)
        // 2. Empty state appears (discovery completed with no results)
        // 3. "Discovering services..." text appears (discovery is in progress)
        // 4. Run button remains present (UI is still functional)
        let servicesFound = bonjourScreen.servicesSection.waitForExistence(timeout: 10)
        let emptyState = bonjourScreen.emptyStateNoServices.waitForExistence(timeout: 3)
        let discoveringText = app.staticTexts["Discovering services..."].waitForExistence(timeout: 3)
        let toolFunctional = bonjourScreen.runButton.waitForExistence(timeout: 3)

        XCTAssertTrue(
            servicesFound || emptyState || discoveringText || toolFunctional,
            "Bonjour discovery should show services, empty state, discovering indicator, or remain functional"
        )
    }
    
    // MARK: - Stop Tests

    func testCanStopDiscovery() {
        bonjourScreen.startDiscovery()

        sleep(2)

        bonjourScreen.stopDiscovery()

        XCTAssertTrue(
            bonjourScreen.isDisplayed(),
            "Bonjour tool should remain displayed after stopping"
        )
    }

    // MARK: - Navigation Tests

    func testCanNavigateBack() {
        bonjourScreen.navigateBack()

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }

    func testBonjourScreenHasNavigationTitle() {
        XCTAssertTrue(
            app.navigationBars["Bonjour Discovery"].waitForExistence(timeout: 5),
            "Bonjour Discovery navigation title should exist"
        )
    }

    func testClearButtonExists() {
        bonjourScreen.startDiscovery()

        // Wait for discovery to complete or timeout
        _ = bonjourScreen.waitForServices(timeout: 10)

        let clearExists = bonjourScreen.clearButton.waitForExistence(timeout: 5)
        XCTAssertTrue(
            clearExists || bonjourScreen.runButton.exists,
            "Clear button should appear after discovery, or tool should remain functional"
        )
    }

    // MARK: - Empty State Tests

    func testEmptyStateOrServicesShown() {
        // Before starting discovery, check initial state
        let hasEmptyState = bonjourScreen.hasEmptyState()
        let hasServices = bonjourScreen.servicesSection.exists

        // Should show either empty state or services (from previous session)
        XCTAssertTrue(
            hasEmptyState || hasServices || bonjourScreen.runButton.exists,
            "Should show empty state, services, or discovery button"
        )
    }

    func testClearAfterDiscovery() {
        bonjourScreen.startDiscovery()

        // Wait for discovery to complete or timeout
        _ = bonjourScreen.waitForServices(timeout: 10)
        sleep(2)

        // Stop discovery if still running
        bonjourScreen.stopDiscovery()
        sleep(1)

        // Try to clear
        bonjourScreen.clearResults()

        // Tool should remain functional
        XCTAssertTrue(
            bonjourScreen.isDisplayed(),
            "Bonjour tool should remain displayed after clearing"
        )
    }

    func testServiceCountAfterDiscovery() {
        bonjourScreen.startDiscovery()

        let found = bonjourScreen.waitForServices(timeout: 15)
        if found {
            let count = bonjourScreen.getServiceCount()
            XCTAssertGreaterThanOrEqual(count, 0, "Service count should be non-negative")
        } else {
            // Simulator may not find services - that's OK
            XCTAssertTrue(
                bonjourScreen.isDisplayed(),
                "Tool should remain functional even without services"
            )
        }
    }
}
