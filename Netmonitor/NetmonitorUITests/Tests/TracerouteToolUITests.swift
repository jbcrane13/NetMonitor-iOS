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

        XCTAssertTrue(
            tracerouteScreen.waitForRunningState(timeout: 8),
            "Traceroute run button should transition to running state after tapping Start Trace"
        )
    }

    func testTracerouteShowsHops() {
        tracerouteScreen
            .enterHost("8.8.8.8")
            .startTrace()

        XCTAssertTrue(
            tracerouteScreen.waitForHops(timeout: 30),
            "Traceroute should render hops after starting a trace"
        )
        XCTAssertGreaterThan(tracerouteScreen.getHopCount(), 0, "Traceroute should contain at least one hop row")
    }
    
    // MARK: - Stop Tests

    func testCanStopTraceroute() {
        tracerouteScreen
            .enterHost("8.8.8.8")
            .startTrace()

        XCTAssertTrue(
            tracerouteScreen.waitForRunningState(timeout: 8),
            "Traceroute should enter running state before Stop is tapped"
        )

        tracerouteScreen.stopTrace()

        XCTAssertTrue(
            tracerouteScreen.waitForIdleState(timeout: 8),
            "Traceroute run button should return to idle state after stopping"
        )
    }

    // MARK: - Navigation Tests

    func testCanNavigateBack() {
        tracerouteScreen.navigateBack()

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }

    // MARK: - Clear Results Tests

    func testCanClearResults() {
        tracerouteScreen
            .enterHost("1.1.1.1")
            .startTrace()

        XCTAssertTrue(
            tracerouteScreen.waitForHops(timeout: 30),
            "Traceroute should produce hop output before clear is tapped"
        )
        XCTAssertTrue(
            tracerouteScreen.clearButton.waitForExistence(timeout: 5),
            "Clear button should appear once traceroute has results"
        )

        // Clear results
        tracerouteScreen.clearResults()

        XCTAssertFalse(
            tracerouteScreen.hopsSection.exists,
            "Traceroute hops section should be removed after clearing results"
        )
    }

    func testTracerouteScreenHasNavigationTitle() {
        XCTAssertTrue(
            app.navigationBars["Traceroute"].waitForExistence(timeout: 5),
            "Traceroute navigation title should exist"
        )
    }

    func testClearButtonExists() {
        tracerouteScreen
            .enterHost("1.1.1.1")
            .startTrace()

        XCTAssertTrue(
            tracerouteScreen.waitForHops(timeout: 30),
            "Traceroute should produce hops before checking clear button"
        )
        let clearExists = tracerouteScreen.clearButton.waitForExistence(timeout: 5)
        XCTAssertTrue(
            clearExists,
            "Clear button should appear after trace completion"
        )
    }

    // MARK: - Functional Verification Tests

    func testMaxHopsPickerChangesValue() {
        guard tracerouteScreen.maxHopsPicker.waitForExistence(timeout: 5) else {
            XCTFail("Max hops picker should exist")
            return
        }

        let initialLabel = tracerouteScreen.maxHopsPicker.label
        tracerouteScreen.maxHopsPicker.tap()

        let hopOptions = ["10", "15", "20", "25", "30"]
        var tapped = false
        for option in hopOptions {
            let btn = app.buttons[option]
            if btn.waitForExistence(timeout: 2) && btn.label != initialLabel {
                btn.tap()
                tapped = true
                break
            }
        }

        XCTAssertTrue(tapped, "Max hops picker should expose selectable menu options")
        XCTAssertTrue(
            tracerouteScreen.maxHopsPicker.exists,
            "Max hops picker should remain after selecting a value"
        )
        XCTAssertNotEqual(
            tracerouteScreen.maxHopsPicker.label,
            initialLabel,
            "Max hops picker label should reflect the new selection"
        )
    }

    func testHopNumbersSequential() {
        tracerouteScreen
            .enterHost("1.1.1.1")
            .startTrace()

        XCTAssertTrue(
            tracerouteScreen.waitForHops(timeout: 30),
            "Traceroute should produce hops before validating hop sequence"
        )

        let hopCount = tracerouteScreen.getHopCount()
        if hopCount >= 2 {
            // Verify both hop 1 and hop 2 exist (sequential numbering)
            let hop1 = app.descendants(matching: .any)["tracerouteTool_hop_1"]
            let hop2 = app.descendants(matching: .any)["tracerouteTool_hop_2"]
            XCTAssertTrue(
                hop1.exists && hop2.exists,
                "Hop numbers should be sequential when multiple hops are displayed"
            )
        } else {
            XCTAssertEqual(hopCount, 1, "Traceroute should produce at least one hop row")
            XCTAssertTrue(
                app.descendants(matching: .any)["tracerouteTool_hop_1"].exists,
                "Single-hop traces should still expose hop 1"
            )
        }
    }
}
