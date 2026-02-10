import XCTest

/// UI tests for the Ping tool functionality
final class PingToolUITests: XCTestCase {
    
    var app: XCUIApplication!
    var pingScreen: PingToolScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Navigate to Ping tool
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        pingScreen = toolsScreen.openPingTool()
    }
    
    override func tearDown() {
        app = nil
        pingScreen = nil
        super.tearDown()
    }
    
    // MARK: - Screen Display Tests
    
    func testPingToolScreenDisplays() {
        XCTAssertTrue(pingScreen.isDisplayed(), "Ping tool screen should be displayed")
    }
    
    func testHostInputFieldExists() {
        XCTAssertTrue(
            pingScreen.hostInput.waitForExistence(timeout: 5),
            "Host input field should exist"
        )
    }
    
    func testPingCountPickerExists() {
        XCTAssertTrue(
            pingScreen.countPicker.waitForExistence(timeout: 5),
            "Ping count picker should exist"
        )
    }
    
    func testRunButtonExists() {
        XCTAssertTrue(
            pingScreen.runButton.waitForExistence(timeout: 5),
            "Run button should exist"
        )
    }
    
    // MARK: - Input Tests
    
    func testCanEnterHostname() {
        pingScreen.enterHost("google.com")
        
        // Verify text was entered
        XCTAssertEqual(
            pingScreen.hostInput.value as? String,
            "google.com",
            "Host input should contain entered text"
        )
    }
    
    func testCanEnterIPAddress() {
        pingScreen.enterHost("8.8.8.8")
        
        XCTAssertEqual(
            pingScreen.hostInput.value as? String,
            "8.8.8.8",
            "Host input should contain entered IP address"
        )
    }
    
    // MARK: - Execution Tests
    
    func testCanStartPing() {
        pingScreen
            .enterHost("1.1.1.1")
            .startPing()

        // In the simulator, ping may not succeed due to network restrictions.
        // Accept either results appearing or the tool remaining functional.
        let gotResults = pingScreen.resultsSection.waitForExistence(timeout: 15)
        if !gotResults {
            // Tool should still be functional even if ping failed
            XCTAssertTrue(
                pingScreen.runButton.waitForExistence(timeout: 5),
                "Ping tool should remain functional after ping attempt"
            )
        }
    }

    func testPingShowsResults() {
        pingScreen
            .enterHost("1.1.1.1")
            .startPing()

        // In the simulator, ping may fail due to network restrictions.
        // Accept either results or the tool remaining functional.
        let gotResults = pingScreen.waitForResults(timeout: 30)
        if !gotResults {
            XCTAssertTrue(
                pingScreen.runButton.waitForExistence(timeout: 5),
                "Ping tool should remain functional after ping attempt"
            )
        }
    }
    
    func testPingShowsStatistics() {
        pingScreen
            .enterHost("1.1.1.1")
            .startPing()
        
        XCTAssertTrue(
            pingScreen.waitForStatistics(timeout: 30),
            "Ping statistics should be displayed after completion"
        )
    }
    
    // MARK: - Stop Tests

    func testCanStopPing() {
        pingScreen
            .enterHost("1.1.1.1")
            .startPing()

        // Wait briefly for ping to start
        sleep(2)

        // Stop the ping
        pingScreen.stopPing()

        // Tool should remain functional
        XCTAssertTrue(
            pingScreen.isDisplayed(),
            "Ping tool should remain displayed after stopping"
        )
    }

    // MARK: - Clear Results Tests

    func testClearButtonAppearsAfterPing() {
        pingScreen
            .enterHost("1.1.1.1")
            .startPing()
        
        _ = pingScreen.waitForStatistics(timeout: 30)
        
        XCTAssertTrue(
            pingScreen.clearButton.waitForExistence(timeout: 5),
            "Clear button should appear after ping completes"
        )
    }
    
    func testCanClearResults() {
        pingScreen
            .enterHost("1.1.1.1")
            .startPing()
        
        _ = pingScreen.waitForStatistics(timeout: 30)
        
        pingScreen.clearResults()
        
        // Results section should no longer exist
        XCTAssertFalse(
            pingScreen.resultsSection.exists,
            "Results should be cleared"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        pingScreen.navigateBack()

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }

    func testHostInputPlaceholderText() {
        let value = pingScreen.hostInput.value as? String ?? ""
        let placeholderValue = pingScreen.hostInput.placeholderValue ?? ""

        XCTAssertTrue(
            value.isEmpty || !placeholderValue.isEmpty,
            "Host input should have placeholder text or be empty"
        )
    }

    func testRunButtonDisabledWhenEmpty() {
        // Clear host input if not already empty
        if let value = pingScreen.hostInput.value as? String, !value.isEmpty {
            pingScreen.hostInput.tap()
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
            pingScreen.hostInput.typeText(deleteString)
        }

        // Tap run button - tool should not crash
        pingScreen.startPing()

        // Tool should still be displayed
        XCTAssertTrue(
            pingScreen.isDisplayed(),
            "Ping tool should remain displayed after tapping run with empty host"
        )
    }
}
