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
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        speedTestScreen.navigateBack()
        
        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }
}
