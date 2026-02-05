import XCTest

/// UI tests for the Port Scanner tool functionality
final class PortScannerToolUITests: XCTestCase {
    
    var app: XCUIApplication!
    var portScanScreen: PortScannerToolScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        portScanScreen = toolsScreen.openPortScannerTool()
    }
    
    override func tearDown() {
        app = nil
        portScanScreen = nil
        super.tearDown()
    }
    
    // MARK: - Screen Display Tests
    
    func testPortScannerToolScreenDisplays() {
        XCTAssertTrue(portScanScreen.isDisplayed(), "Port Scanner tool screen should be displayed")
    }
    
    func testHostInputFieldExists() {
        XCTAssertTrue(
            portScanScreen.hostInput.waitForExistence(timeout: 5),
            "Host input field should exist"
        )
    }
    
    func testPortRangePickerExists() {
        XCTAssertTrue(
            portScanScreen.portRangePicker.waitForExistence(timeout: 5),
            "Port range picker should exist"
        )
    }
    
    func testRunButtonExists() {
        XCTAssertTrue(
            portScanScreen.runButton.waitForExistence(timeout: 5),
            "Run button should exist"
        )
    }
    
    // MARK: - Input Tests
    
    func testCanEnterHost() {
        portScanScreen.enterHost("scanme.nmap.org")
        
        XCTAssertEqual(
            portScanScreen.hostInput.value as? String,
            "scanme.nmap.org",
            "Host input should contain entered text"
        )
    }
    
    // MARK: - Execution Tests
    
    func testCanStartPortScan() {
        portScanScreen
            .enterHost("scanme.nmap.org")
            .startScan()
        
        // Progress indicator should appear or results should appear
        let hasProgress = portScanScreen.isScanning()
        let hasResults = portScanScreen.resultsSection.waitForExistence(timeout: 60)
        
        XCTAssertTrue(
            hasProgress || hasResults,
            "Port scan should show progress or results"
        )
    }
    
    func testPortScanShowsResults() {
        portScanScreen
            .enterHost("scanme.nmap.org")
            .startScan()
        
        XCTAssertTrue(
            portScanScreen.waitForResults(timeout: 120),
            "Port scan should show results"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        portScanScreen.navigateBack()
        
        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }
}
