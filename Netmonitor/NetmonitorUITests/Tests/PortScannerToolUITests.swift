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

        let hasProgress = portScanScreen.progressIndicator.waitForExistence(timeout: 8)
        let enteredRunningState = portScanScreen.waitForRunningState(timeout: 8)

        XCTAssertTrue(
            hasProgress || enteredRunningState,
            "Port scan should enter an active scanning state after tapping Start Scan"
        )
    }

    func testPortScanShowsResults() {
        portScanScreen
            .enterHost("scanme.nmap.org")
            .startScan()

        XCTAssertTrue(
            portScanScreen.waitForRunningState(timeout: 8),
            "Port scanner should start running after Start Scan is tapped"
        )
        XCTAssertTrue(
            portScanScreen.waitForIdleState(timeout: 70),
            "Port scanner should eventually return to idle state when scan completes"
        )
    }
    
    // MARK: - Stop Tests

    func testCanStopPortScan() {
        portScanScreen
            .enterHost("scanme.nmap.org")
            .startScan()

        XCTAssertTrue(
            portScanScreen.waitForRunningState(timeout: 8),
            "Port scanner should enter running state before Stop is tapped"
        )

        portScanScreen.stopScan()

        XCTAssertTrue(
            portScanScreen.waitForIdleState(timeout: 8),
            "Port scanner should return to idle state after stopping"
        )
    }

    // MARK: - Navigation Tests

    func testCanNavigateBack() {
        portScanScreen.navigateBack()

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }

    func testPortRangePickerInteraction() {
        portScanScreen.portRangePicker.tap()

        // Verify picker responds by checking if menu appears or picker still exists
        let hasMenu = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Common' OR label CONTAINS[c] 'Well-Known' OR label CONTAINS[c] 'Custom'")).count > 0

        XCTAssertTrue(
            hasMenu,
            "Port range picker should present menu options when tapped"
        )
    }

    func testClearButtonExists() throws {
        portScanScreen
            .enterHost("scanme.nmap.org")
            .startScan()

        XCTAssertTrue(
            portScanScreen.waitForIdleState(timeout: 70),
            "Port scan should complete before clear button is checked"
        )

        guard portScanScreen.resultsSection.exists else {
            throw XCTSkip("No open ports were found in this run; clear button only appears when result rows exist.")
        }

        XCTAssertTrue(
            portScanScreen.clearButton.waitForExistence(timeout: 5),
            "Clear button should appear when port scan result rows are present"
        )
    }

    // MARK: - Custom Range Tests

    func testCanSelectCustomPortRange() {
        // Tap the port range picker to open it
        portScanScreen.portRangePicker.tap()

        // Look for "Custom" option in the menu
        let customOption = app.buttons["Custom"]
        XCTAssertTrue(customOption.waitForExistence(timeout: 3), "Custom option should be available in port range picker")
        customOption.tap()

        XCTAssertTrue(
            portScanScreen.startPortInput.waitForExistence(timeout: 5),
            "Start port input should appear when Custom range is selected"
        )
        XCTAssertTrue(
            portScanScreen.endPortInput.waitForExistence(timeout: 5),
            "End port input should appear when Custom range is selected"
        )
    }

    func testPortScannerScreenHasNavigationTitle() {
        XCTAssertTrue(
            app.navigationBars["Port Scanner"].waitForExistence(timeout: 5),
            "Port Scanner navigation title should exist"
        )
    }

    // MARK: - Custom Range Functional Tests

    func testCustomPortRangeInputsAppear() {
        portScanScreen.portRangePicker.tap()

        let customOption = app.buttons["Custom"]
        XCTAssertTrue(customOption.waitForExistence(timeout: 3), "Custom option should be available in port range picker")
        customOption.tap()

        let startExists = portScanScreen.startPortInput.waitForExistence(timeout: 5)
        let endExists = portScanScreen.endPortInput.waitForExistence(timeout: 5)
        XCTAssertTrue(
            startExists && endExists,
            "Start and end port input fields should appear when Custom range is selected"
        )
    }

    func testCustomPortRangeValidation() {
        portScanScreen.portRangePicker.tap()
        let customOption = app.buttons["Custom"]
        XCTAssertTrue(customOption.waitForExistence(timeout: 3), "Custom option should be available in port range picker")
        customOption.tap()

        // Enter an invalid range: start > end
        if portScanScreen.startPortInput.waitForExistence(timeout: 5) {
            portScanScreen.startPortInput.tap()
            portScanScreen.startPortInput.typeText("9000")
        }
        if portScanScreen.endPortInput.waitForExistence(timeout: 5) {
            portScanScreen.endPortInput.tap()
            portScanScreen.endPortInput.typeText("80")
        }

        portScanScreen.enterHost("scanme.nmap.org")
        portScanScreen.startScan()

        XCTAssertFalse(
            portScanScreen.waitForRunningState(timeout: 3),
            "Invalid custom port range should not start a scan"
        )
    }

    func testProgressBarDuringScan() {
        portScanScreen
            .enterHost("scanme.nmap.org")
            .startScan()

        // Immediately check for progress indicator / running transition
        let hasProgress = portScanScreen.progressIndicator.waitForExistence(timeout: 5)
        let isRunning = portScanScreen.waitForRunningState(timeout: 5)

        XCTAssertTrue(
            hasProgress || isRunning,
            "Port scanner should show active-progress UI while a scan is running"
        )
    }
}
