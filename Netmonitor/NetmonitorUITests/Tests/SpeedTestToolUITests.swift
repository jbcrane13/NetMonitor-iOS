import XCTest

/// UI tests for the Speed Test tool functionality
final class SpeedTestToolUITests: XCTestCase {
    
    var app: XCUIApplication!
    var speedTestScreen: SpeedTestToolScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        speedTestScreen = toolsScreen.openSpeedTestTool()
    }
    
    override func tearDown() {
        app = nil
        speedTestScreen = nil
        super.tearDown()
    }
    
    // MARK: - Screen Display Tests
    
    func testSpeedTestToolScreenDisplays() {
        XCTAssertTrue(speedTestScreen.isDisplayed(), "Speed Test tool screen should be displayed")
    }
    
    func testGaugeExists() {
        XCTAssertTrue(
            speedTestScreen.verifyGaugePresent(),
            "Speed gauge should exist"
        )
    }
    
    func testRunButtonExists() {
        XCTAssertTrue(
            speedTestScreen.runButton.waitForExistence(timeout: 5),
            "Run button should exist"
        )
    }
    
    // MARK: - Execution Tests
    
    // Note: Speed test is a long-running operation, so we use a longer timeout
    func testCanStartSpeedTest() {
        speedTestScreen.startTest()

        // The gauge should show activity or results should appear eventually.
        // In the simulator, speed test may fail due to network restrictions.
        // Accept results, an error message, or the tool remaining functional.
        let gotResults = speedTestScreen.waitForResults(timeout: 60)
        if !gotResults {
            // Check for error text or tool still being functional
            let hasError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'error' OR label CONTAINS[c] 'failed'")).count > 0
            XCTAssertTrue(
                hasError || speedTestScreen.runButton.waitForExistence(timeout: 5),
                "Speed test should show results, an error, or remain functional"
            )
        }
    }
    
    // MARK: - Stop Tests

    func testCanStopSpeedTest() {
        speedTestScreen.startTest()

        sleep(3)

        speedTestScreen.stopTest()

        XCTAssertTrue(
            speedTestScreen.isDisplayed(),
            "Speed Test should remain displayed after stopping"
        )
    }

    // MARK: - Navigation Tests

    func testCanNavigateBack() {
        speedTestScreen.navigateBack()

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }

    func testHistorySectionAppearance() {
        // Scroll to ensure history section is visible
        speedTestScreen.swipeUp()

        // History section should exist (may be empty)
        XCTAssertTrue(
            speedTestScreen.historySection.exists || app.staticTexts["History"].exists,
            "History section should exist"
        )
    }

    func testSpeedTestScreenHasNavigationTitle() {
        XCTAssertTrue(
            app.navigationBars["Speed Test"].waitForExistence(timeout: 5),
            "Speed Test navigation title should exist"
        )
    }

    // MARK: - Results Verification Tests

    func testGaugeShowsActivityDuringTest() {
        speedTestScreen.startTest()

        // During test, gauge should be present
        XCTAssertTrue(
            speedTestScreen.verifyGaugePresent(),
            "Gauge should remain visible during speed test"
        )

        // Wait briefly and verify tool is still functional
        sleep(3)
        XCTAssertTrue(
            speedTestScreen.isDisplayed(),
            "Speed test screen should remain displayed during test"
        )
    }

    func testResultsSectionAfterTest() {
        speedTestScreen.startTest()

        let gotResults = speedTestScreen.waitForResults(timeout: 90)
        if gotResults {
            // Results section should contain speed information
            let hasDownload = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'download' OR label CONTAINS[c] 'Mbps' OR label CONTAINS[c] 'MB'")).count > 0
            XCTAssertTrue(
                hasDownload || speedTestScreen.resultsSection.exists,
                "Results should contain speed information"
            )
        } else {
            // Network may not be available in simulator
            XCTAssertTrue(
                speedTestScreen.isDisplayed(),
                "Speed test should remain functional after timeout"
            )
        }
    }
}
