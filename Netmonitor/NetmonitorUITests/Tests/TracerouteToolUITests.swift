import XCTest

/// UI tests for the Traceroute tool functionality
final class TracerouteToolUITests: XCTestCase {
    
    var app: XCUIApplication!
    var tracerouteScreen: TracerouteToolScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        tracerouteScreen = toolsScreen.openTracerouteTool()
    }
    
    override func tearDown() {
        app = nil
        tracerouteScreen = nil
        super.tearDown()
    }
    
    // MARK: - Screen Display Tests
    
    func testTracerouteToolScreenDisplays() {
        XCTAssertTrue(tracerouteScreen.isDisplayed(), "Traceroute tool screen should be displayed")
    }
    
    func testHostInputFieldExists() {
        XCTAssertTrue(
            tracerouteScreen.hostInput.waitForExistence(timeout: 5),
            "Host input field should exist"
        )
    }
    
    func testMaxHopsPickerExists() {
        XCTAssertTrue(
            tracerouteScreen.maxHopsPicker.waitForExistence(timeout: 5),
            "Max hops picker should exist"
        )
    }
    
    func testRunButtonExists() {
        XCTAssertTrue(
            tracerouteScreen.runButton.waitForExistence(timeout: 5),
            "Run button should exist"
        )
    }
    
    // MARK: - Input Tests
    
    func testCanEnterHostname() {
        tracerouteScreen.enterHost("google.com")
        
        XCTAssertEqual(
            tracerouteScreen.hostInput.value as? String,
            "google.com",
            "Host input should contain entered text"
        )
    }
    
    // MARK: - Execution Tests
    
    func testCanStartTraceroute() {
        tracerouteScreen
            .enterHost("1.1.1.1")
            .startTrace()
        
        // Wait for hops to appear
        XCTAssertTrue(
            tracerouteScreen.waitForHops(timeout: 60),
            "Traceroute should show hops"
        )
    }
    
    func testTracerouteShowsHops() {
        tracerouteScreen
            .enterHost("8.8.8.8")
            .startTrace()
        
        XCTAssertTrue(
            tracerouteScreen.waitForHops(timeout: 60),
            "Traceroute hops should be displayed"
        )
        
        // Should have at least one hop
        XCTAssertGreaterThan(
            tracerouteScreen.getHopCount(),
            0,
            "Should display at least one hop"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        tracerouteScreen.navigateBack()
        
        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }
}
