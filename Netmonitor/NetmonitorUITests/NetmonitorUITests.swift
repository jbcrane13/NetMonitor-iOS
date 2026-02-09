import XCTest

final class NetmonitorUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Dashboard Flow

    func testDashboardLoads() {
        let dashboardScreen = DashboardScreen(app: app)
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard screen should load")
    }

    func testDashboardTabExists() {
        // The tab bar should have a Dashboard tab
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
    }

    // MARK: - Settings Navigation

    func testSettingsScreenLoads() {
        // Navigate to Settings via Dashboard settings button
        let dashboardScreen = DashboardScreen(app: app)
        let settingsScreen = dashboardScreen.openSettings()
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings screen should load")
    }

    func testSettingsPingCountExists() {
        let dashboardScreen = DashboardScreen(app: app)
        let settingsScreen = dashboardScreen.openSettings()
        XCTAssertTrue(
            settingsScreen.pingCountStepper.waitForExistence(timeout: 5) ||
            settingsScreen.pingCountText.waitForExistence(timeout: 3),
            "Ping count stepper should exist"
        )
    }

    func testSettingsClearHistoryButton() {
        let dashboardScreen = DashboardScreen(app: app)
        let settingsScreen = dashboardScreen.openSettings()
        settingsScreen.swipeUp()
        let clearButton = settingsScreen.clearHistoryButton
        if clearButton.waitForExistence(timeout: 5) {
            clearButton.tap()
            // Alert should appear
            let alert = app.alerts["Clear History"]
            XCTAssertTrue(alert.waitForExistence(timeout: 3), "Clear history alert should appear")
            alert.buttons["Cancel"].tap()
        }
    }

    func testSettingsClearCacheButton() {
        let dashboardScreen = DashboardScreen(app: app)
        let settingsScreen = dashboardScreen.openSettings()
        settingsScreen.swipeUp()
        let clearCacheButton = settingsScreen.clearCacheButton
        if clearCacheButton.waitForExistence(timeout: 5) {
            clearCacheButton.tap()
            let alert = app.alerts["Clear All Cached Data"]
            XCTAssertTrue(alert.waitForExistence(timeout: 3), "Clear cache alert should appear")
            alert.buttons["Cancel"].tap()
        }
    }

    // MARK: - Tools Navigation

    func testToolsTabExists() {
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        XCTAssertTrue(toolsScreen.isDisplayed(), "Tools screen should load")
    }

    // MARK: - Network Map Navigation

    func testNetworkMapTabExists() {
        let mapScreen = NetworkMapScreen(app: app)
        mapScreen.navigateToNetworkMap()
        XCTAssertTrue(mapScreen.isDisplayed(), "Network Map screen should load")
    }

    // MARK: - Tool Execution - Ping

    func testPingToolNavigation() {
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        let pingScreen = toolsScreen.openPingTool()
        XCTAssertTrue(pingScreen.isDisplayed(), "Ping tool screen should load")
    }

    func testPortScannerToolNavigation() {
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        let portScanScreen = toolsScreen.openPortScannerTool()
        XCTAssertTrue(portScanScreen.isDisplayed(), "Port Scanner screen should load")
    }
}
