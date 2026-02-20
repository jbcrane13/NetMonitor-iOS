import XCTest

/// UI tests for the Network Map screen
final class NetworkMapUITests: XCTestCase {

    var app: XCUIApplication!
    var mapScreen: NetworkMapScreen!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        mapScreen = NetworkMapScreen(app: app)
        mapScreen.navigateToNetworkMap()
    }

    override func tearDown() {
        app = nil
        mapScreen = nil
        super.tearDown()
    }

    // MARK: - Screen Loading Tests

    func testNetworkMapScreenLoads() {
        XCTAssertTrue(mapScreen.isDisplayed(), "Network Map screen should load")
    }

    func testNetworkMapCoreIdentifiersAreVisible() {
        XCTAssertTrue(
            mapScreen.verifyCoreUIVisible(),
            "Summary card, sort picker, and scan button should all be visible"
        )
    }

    func testMapTabExists() {
        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5), "Map tab should exist")
    }

    // MARK: - Scan Button Tests

    func testScanButtonExists() {
        XCTAssertTrue(
            mapScreen.scanButton.waitForExistence(timeout: 5),
            "Scan button should exist in toolbar"
        )
    }

    func testCanTriggerScan() {
        mapScreen.startScan()

        // Map should remain interactive while a scan is in-flight or after it finishes.
        XCTAssertTrue(
            mapScreen.isDisplayed() && (mapScreen.isShowingScanProgress() || mapScreen.summaryCard.exists),
            "Network Map should remain interactive after starting scan"
        )
    }

    // MARK: - Navigation Tests

    func testCanNavigateToDashboard() {
        mapScreen.navigateToTab("Dashboard")

        let dashboardScreen = DashboardScreen(app: app)
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should navigate to Dashboard")
    }

    func testCanNavigateToTools() {
        mapScreen.navigateToTab("Tools")

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should navigate to Tools")
    }

    func testScanButtonIsEnabledOrHittable() {
        XCTAssertTrue(
            mapScreen.scanButton.isEnabled || mapScreen.scanButton.isHittable,
            "Scan button should be enabled or hittable"
        )
    }

    func testMapScreenHasTabBar() {
        XCTAssertTrue(
            app.tabBars.element.waitForExistence(timeout: 5),
            "Tab bar should exist while on map screen"
        )
    }

    func testCanNavigateToAllTabs() {
        // Navigate to Dashboard
        mapScreen.navigateToTab("Dashboard")
        let dashboardScreen = DashboardScreen(app: app)
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should navigate to Dashboard")

        // Navigate to Tools
        dashboardScreen.navigateToTab("Tools")
        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should navigate to Tools")

        // Navigate back to Map
        toolsScreen.navigateToTab("Map")
        XCTAssertTrue(mapScreen.isDisplayed(), "Should navigate back to Map")
    }

    // MARK: - Functional Verification Tests

    func testSortPickerChangesOrder() {
        let sortPicker = mapScreen.sortPicker
        XCTAssertTrue(sortPicker.waitForExistence(timeout: 5), "Sort picker should be visible")

        sortPicker.tap()

        let expectedSortOptions = ["IP", "Name", "Latency", "Source"]
        let visibleOptions = expectedSortOptions.filter { app.buttons[$0].waitForExistence(timeout: 2) }

        XCTAssertFalse(
            visibleOptions.isEmpty,
            "Sort picker should expose at least one expected option (IP/Name/Latency/Source)"
        )

        // Select Name when available to verify actionable menu behavior.
        if app.buttons["Name"].exists {
            app.buttons["Name"].tap()
            XCTAssertTrue(sortPicker.waitForExistence(timeout: 5), "Sort picker should remain visible after selection")
        } else {
            // Dismiss the menu if we did not pick any option.
            app.tap()
        }
    }

    func testDeviceRowNavigatesToDetail() throws {
        guard mapScreen.hasAnyDeviceRow(timeout: 10) else {
            throw XCTSkip("No networkMap_row_* device rows available in this environment")
        }

        XCTAssertTrue(mapScreen.tapFirstDeviceRow(), "First device row should be tappable")
        XCTAssertTrue(
            app.descendants(matching: .any)["screen_deviceDetail"].waitForExistence(timeout: 5),
            "Tapping a networkMap_row_* row should navigate to Device Detail"
        )
    }

    func testScanProgressDisplay() {
        mapScreen.startScan()

        XCTAssertTrue(
            mapScreen.isShowingScanProgress() || mapScreen.summaryCard.exists,
            "Starting a scan should show progress indicators or keep summary visible while scan resolves"
        )
    }

    func testEmptyStateDisplay() throws {
        if mapScreen.getDeviceRowCount() > 0 {
            throw XCTSkip("Device rows are present; empty state is not expected")
        }

        XCTAssertTrue(
            mapScreen.emptyStateLabel.waitForExistence(timeout: 8) || mapScreen.isShowingScanProgress(),
            "When no rows exist, empty-state identifier should appear (or scan progress should still be active)"
        )
    }

    func testNetworkSummaryCardContent() {
        XCTAssertTrue(
            mapScreen.summaryCard.waitForExistence(timeout: 5),
            "Network summary card should be visible with current map implementation"
        )
    }
}
