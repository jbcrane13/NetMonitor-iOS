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

        XCTAssertTrue(
            pingScreen.waitForRunningState(timeout: 8),
            "Ping run button should transition to running state after tapping Start Ping"
        )
    }

    func testPingShowsResults() {
        pingScreen
            .enterHost("1.1.1.1")
            .startPing()

        XCTAssertTrue(
            pingScreen.waitForResults(timeout: 30),
            "Ping results section should appear after running a ping"
        )
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

        XCTAssertTrue(
            pingScreen.waitForRunningState(timeout: 8),
            "Ping should enter running state before Stop is tapped"
        )

        // Stop the ping
        pingScreen.stopPing()

        XCTAssertTrue(
            pingScreen.waitForIdleState(timeout: 8),
            "Ping run button should return to idle state after stopping"
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
        let placeholder = pingScreen.hostInput.placeholderValue ?? ""

        XCTAssertTrue(
            value.localizedCaseInsensitiveContains("hostname") ||
            placeholder.localizedCaseInsensitiveContains("hostname"),
            "Host input should expose the hostname/IP placeholder text"
        )
    }

    func testRunButtonDisabledWhenEmpty() {
        // Clear host input if not already empty
        if let value = pingScreen.hostInput.value as? String, !value.isEmpty {
            pingScreen.hostInput.tap()
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
            pingScreen.hostInput.typeText(deleteString)
        }

        // Tap run button with empty host
        pingScreen.startPing()

        XCTAssertFalse(
            pingScreen.waitForRunningState(timeout: 3),
            "Ping should not enter running state when host input is empty"
        )
    }

    // MARK: - Functional Verification Tests

    func testPingCountPickerChangesValue() {
        guard pingScreen.countPicker.waitForExistence(timeout: 5) else {
            XCTFail("Count picker should exist")
            return
        }

        let initialLabel = pingScreen.countPicker.label
        pingScreen.countPicker.tap()

        // Look for count options in the picker menu
        let countOptions = ["5", "10", "20", "50", "100"]
        var selectedOption = false
        for option in countOptions {
            let button = app.buttons[option]
            if button.waitForExistence(timeout: 2) && button.label != initialLabel {
                button.tap()
                selectedOption = true
                break
            }
        }

        XCTAssertTrue(selectedOption, "Count picker should expose at least one selectable alternative value")
        let updatedLabel = pingScreen.countPicker.label
        XCTAssertNotEqual(updatedLabel, initialLabel, "Picker label should reflect the new ping count")
    }

    func testPingStatisticsReasonableValues() {
        pingScreen
            .enterHost("1.1.1.1")
            .startPing()

        XCTAssertTrue(
            pingScreen.waitForStatistics(timeout: 30),
            "Ping statistics card should appear after ping completion"
        )

        let statsTexts = pingScreen.statisticsCard.staticTexts
        let hasMin = statsTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Min'")).count > 0
        let hasAvg = statsTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Avg'")).count > 0
        let hasMax = statsTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Max'")).count > 0
        let hasLatencyValue = statsTexts.matching(NSPredicate(format: "label CONTAINS[c] 'ms'")).count > 0

        XCTAssertTrue(hasMin, "Statistics should include Min latency label")
        XCTAssertTrue(hasAvg, "Statistics should include Avg latency label")
        XCTAssertTrue(hasMax, "Statistics should include Max latency label")
        XCTAssertTrue(hasLatencyValue, "Statistics card should include at least one latency value in milliseconds")
    }

    func testHostPreFilledFromTarget() {
        // Verify the host field accepts and retains a value (simulates a pre-filled target)
        pingScreen.enterHost("192.168.1.1")

        let value = pingScreen.hostInput.value as? String ?? ""
        XCTAssertFalse(value.isEmpty, "Host field should retain entered value")
        XCTAssertTrue(
            value.contains("192.168.1.1"),
            "Host field should display the entered IP address"
        )
    }
}
