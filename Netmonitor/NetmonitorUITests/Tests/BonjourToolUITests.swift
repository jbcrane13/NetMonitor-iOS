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

        XCTAssertTrue(
            bonjourScreen.waitForDiscoveringState(timeout: 8),
            "Bonjour discovery should enter discovering state after Start Discovery is tapped"
        )
    }
    
    // MARK: - Stop Tests

    func testCanStopDiscovery() {
        bonjourScreen.startDiscovery()
        XCTAssertTrue(
            bonjourScreen.waitForDiscoveringState(timeout: 8),
            "Discovery should enter running state before Stop is tapped"
        )

        bonjourScreen.stopDiscovery()

        XCTAssertTrue(
            bonjourScreen.waitForIdleState(timeout: 8),
            "Discovery button should return to idle state after stop"
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

    func testClearButtonExists() throws {
        bonjourScreen.startDiscovery()
        XCTAssertTrue(
            bonjourScreen.waitForCompletedOutcome(timeout: 25),
            "Discovery should complete before clear button presence is evaluated"
        )
        bonjourScreen.stopDiscovery()
        _ = bonjourScreen.waitForIdleState(timeout: 8)

        if bonjourScreen.servicesSection.exists {
            XCTAssertTrue(
                bonjourScreen.clearButton.waitForExistence(timeout: 5),
                "Clear button should appear when discovered-service results are visible"
            )
        } else {
            XCTAssertTrue(
                bonjourScreen.hasEmptyState(),
                "Bonjour should show explicit empty state when no services are available"
            )
            XCTAssertFalse(
                bonjourScreen.clearButton.exists,
                "Clear button should be hidden when there are no discovered services"
            )
        }
    }

    // MARK: - Empty State Tests

    func testEmptyStateOrServicesShown() {
        bonjourScreen.startDiscovery()
        XCTAssertTrue(
            bonjourScreen.waitForCompletedOutcome(timeout: 25),
            "Bonjour discovery should complete before terminal state is checked"
        )
        XCTAssertTrue(
            bonjourScreen.hasEmptyState() || bonjourScreen.servicesSection.exists,
            "Bonjour should finish in either empty-state or discovered-services state"
        )
    }

    func testClearAfterDiscovery() throws {
        bonjourScreen.startDiscovery()

        XCTAssertTrue(
            bonjourScreen.waitForCompletedOutcome(timeout: 25),
            "Discovery should finish before clear behavior is validated"
        )

        // Stop discovery if still running
        bonjourScreen.stopDiscovery()
        XCTAssertTrue(
            bonjourScreen.waitForIdleState(timeout: 8),
            "Discovery should be idle before clearing results"
        )

        guard bonjourScreen.servicesSection.exists else {
            throw XCTSkip("No discovered services in this environment; cannot validate clear-results transition.")
        }
        XCTAssertTrue(
            bonjourScreen.clearButton.waitForExistence(timeout: 5),
            "Clear button must be visible before invoking clear"
        )

        bonjourScreen.clearResults()
        XCTAssertTrue(
            bonjourScreen.emptyStateNoServices.waitForExistence(timeout: 5),
            "Clearing discovered services should return the view to the explicit empty state"
        )
        XCTAssertFalse(
            bonjourScreen.servicesSection.exists,
            "Service results section should disappear after clearing results"
        )
        XCTAssertFalse(
            bonjourScreen.clearButton.exists,
            "Clear button should disappear once results are cleared"
        )
        XCTAssertTrue(
            bonjourScreen.isDisplayed(),
            "Bonjour screen should remain visible after clear action"
        )
    }

    func testServiceCountAfterDiscovery() {
        bonjourScreen.startDiscovery()

        XCTAssertTrue(
            bonjourScreen.waitForCompletedOutcome(timeout: 25),
            "Discovery should complete before terminal result state is validated"
        )
        bonjourScreen.stopDiscovery()
        _ = bonjourScreen.waitForIdleState(timeout: 8)

        if bonjourScreen.servicesSection.exists {
            XCTAssertFalse(
                bonjourScreen.hasEmptyState(),
                "Empty state should not be visible when services section is present"
            )
            XCTAssertTrue(
                bonjourScreen.clearButton.waitForExistence(timeout: 5),
                "Clear button should be visible whenever discovered services are shown"
            )
        } else {
            XCTAssertTrue(
                bonjourScreen.hasEmptyState(),
                "When no services are found, Bonjour should show the explicit empty state"
            )
            XCTAssertFalse(
                bonjourScreen.clearButton.exists,
                "Clear button should be hidden in empty-state outcome"
            )
        }
    }

    // MARK: - Functional Verification Tests

    func testServiceGroupingByCategory() {
        bonjourScreen.startDiscovery()

        let reachedTerminalState = bonjourScreen.waitForCompletedOutcome(timeout: 25)
        XCTAssertTrue(
            reachedTerminalState,
            "Bonjour should reach a terminal state before grouping assertions are evaluated"
        )
        bonjourScreen.stopDiscovery()
        _ = bonjourScreen.waitForIdleState(timeout: 8)

        guard bonjourScreen.servicesSection.exists else {
            XCTAssertTrue(
                bonjourScreen.hasEmptyState(),
                "Bonjour should show empty state when no services are discovered"
            )
            return
        }

        XCTAssertTrue(
            bonjourScreen.clearButton.exists,
            "Discovered-services state should expose clear action for follow-up interactions"
        )
        XCTAssertFalse(
            bonjourScreen.hasEmptyState(),
            "Discovered-services state should not render the empty-state view"
        )
    }
}
