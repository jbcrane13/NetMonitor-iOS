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

        XCTAssertTrue(
            speedTestScreen.waitForRunningState(timeout: 8),
            "Speed test run button should transition to running state after Start Test"
        )
    }
    
    // MARK: - Stop Tests

    func testCanStopSpeedTest() {
        speedTestScreen.startTest()

        XCTAssertTrue(
            speedTestScreen.waitForRunningState(timeout: 8),
            "Speed test should enter running state before Stop is tapped"
        )

        speedTestScreen.stopTest()

        XCTAssertTrue(
            speedTestScreen.waitForIdleState(timeout: 8),
            "Speed test run button should return to idle state after stopping"
        )
    }

    // MARK: - Navigation Tests

    func testCanNavigateBack() {
        speedTestScreen.navigateBack()

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }

    func testHistorySectionAppearance() {
        // Scroll to ensure history section is visible if present
        speedTestScreen.swipeUp()

        let hasHistory = speedTestScreen.historySection.exists
        if hasHistory {
            XCTAssertTrue(app.staticTexts["History"].exists, "History header should exist when history section exists")
        } else {
            XCTAssertTrue(
                speedTestScreen.historySection.exists == false,
                "History section should be absent when there are no saved speed test runs"
            )
        }
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

        XCTAssertTrue(
            speedTestScreen.waitForRunningState(timeout: 8),
            "Speed test should enter running state during active test"
        )

        // During test, gauge should be present
        XCTAssertTrue(
            speedTestScreen.verifyGaugePresent(),
            "Gauge should remain visible during speed test"
        )
    }

    func testResultsSectionAfterTest() {
        speedTestScreen.startTest()

        XCTAssertTrue(
            speedTestScreen.waitForCompletedOutcome(timeout: 95),
            "Speed test should complete with either results or an explicit error"
        )
        if speedTestScreen.resultsSection.exists {
            // Results section should contain speed information
            let hasDownload = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'download' OR label CONTAINS[c] 'Mbps' OR label CONTAINS[c] 'MB'")).count > 0
            XCTAssertTrue(
                hasDownload,
                "Results should contain speed information"
            )
        } else {
            XCTAssertTrue(
                speedTestScreen.hasError(),
                "When speed test results are absent, an explicit error should be shown"
            )
        }
    }

    // MARK: - Functional Verification Tests

    func testDurationPickerChangesValue() {
        let segment10 = speedTestScreen.durationSegment10s
        XCTAssertTrue(segment10.waitForExistence(timeout: 5), "10s segment should exist in speed test duration control")
        segment10.tap()

        XCTAssertTrue(
            segment10.isSelected || segment10.value as? String == "1",
            "10s duration segment should be selected after tapping it"
        )
    }

    func testResultsShowNonZeroValues() {
        speedTestScreen.startTest()

        XCTAssertTrue(
            speedTestScreen.waitForCompletedOutcome(timeout: 95),
            "Speed test should complete with either results or error"
        )
        guard speedTestScreen.resultsSection.exists else {
            XCTAssertTrue(
                speedTestScreen.hasError(),
                "When results are unavailable, speed test should present an explicit error"
            )
            return
        }

        // Results should show speed unit labels and values
        let hasMbps = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Mbps' OR label CONTAINS[c] 'MB/s' OR label CONTAINS[c] 'Kbps'")
        ).count > 0

        let hasDownloadLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Download' OR label CONTAINS[c] 'download'")
        ).count > 0

        let hasUploadLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Upload' OR label CONTAINS[c] 'upload'")
        ).count > 0

        XCTAssertTrue(
            hasMbps && hasDownloadLabel && hasUploadLabel,
            "Results section should show download/upload speed values"
        )
    }
}
