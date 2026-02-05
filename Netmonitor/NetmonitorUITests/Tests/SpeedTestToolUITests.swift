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
        
        // The gauge should show activity or results should appear eventually
        // We'll wait for results with a longer timeout since speed tests take time
        XCTAssertTrue(
            speedTestScreen.waitForResults(timeout: 120),
            "Speed test should complete and show results"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        speedTestScreen.navigateBack()
        
        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }
}
