import XCTest

/// Comprehensive UI tests for the Dashboard screen
final class DashboardUITests: XCTestCase {
    
    var app: XCUIApplication!
    var dashboardScreen: DashboardScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        dashboardScreen = DashboardScreen(app: app)
    }
    
    override func tearDown() {
        app = nil
        dashboardScreen = nil
        super.tearDown()
    }
    
    // MARK: - Dashboard Loading Tests
    
    func testDashboardLoadsCorrectly() {
        // Dashboard is the default tab, should load immediately
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Dashboard screen should be displayed on launch")
    }
    
    func testDashboardIsDefaultTab() {
        // Verify we're on Dashboard tab by default
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 5), "Dashboard tab should exist")
        XCTAssertTrue(dashboardTab.isSelected, "Dashboard tab should be selected by default")
    }
    
    // MARK: - Connection Status Header Tests
    
    func testConnectionStatusHeaderDisplays() {
        XCTAssertTrue(
            dashboardScreen.connectionStatusHeader.waitForExistence(timeout: 5),
            "Connection status header should be displayed"
        )
    }
    
    // MARK: - Session Card Tests
    
    func testSessionCardDisplays() {
        XCTAssertTrue(
            dashboardScreen.sessionCard.waitForExistence(timeout: 5),
            "Session card should be displayed"
        )
    }
    
    func testSessionCardShowsSessionInfo() {
        let sessionCard = dashboardScreen.sessionCard
        XCTAssertTrue(sessionCard.waitForExistence(timeout: 5))
        
        // Session card should contain "Session" text
        XCTAssertTrue(
            app.staticTexts["Session"].exists,
            "Session card should show 'Session' label"
        )
    }
    
    // MARK: - WiFi/Connection Card Tests
    
    func testWiFiCardDisplays() {
        XCTAssertTrue(
            dashboardScreen.wifiCard.waitForExistence(timeout: 5),
            "WiFi/Connection card should be displayed"
        )
    }
    
    func testConnectionCardShowsConnectionStatus() {
        let wifiCard = dashboardScreen.wifiCard
        XCTAssertTrue(wifiCard.waitForExistence(timeout: 5))
        
        // Should have "Connection" label
        XCTAssertTrue(
            app.staticTexts["Connection"].exists,
            "Connection card should show 'Connection' label"
        )
    }
    
    // MARK: - Gateway Card Tests
    
    func testGatewayCardDisplays() {
        XCTAssertTrue(
            dashboardScreen.gatewayCard.waitForExistence(timeout: 5),
            "Gateway card should be displayed"
        )
    }
    
    func testGatewayCardShowsGatewayInfo() {
        let gatewayCard = dashboardScreen.gatewayCard
        XCTAssertTrue(gatewayCard.waitForExistence(timeout: 5))
        
        // Should have "Gateway" label
        XCTAssertTrue(
            app.staticTexts["Gateway"].exists,
            "Gateway card should show 'Gateway' label"
        )
    }
    
    // MARK: - ISP/Internet Card Tests
    
    func testISPCardDisplays() {
        // May need to scroll to see this card
        dashboardScreen.swipeUp()
        
        XCTAssertTrue(
            dashboardScreen.ispCard.waitForExistence(timeout: 5),
            "ISP/Internet card should be displayed"
        )
    }
    
    func testInternetCardShowsInternetInfo() {
        dashboardScreen.swipeUp()
        
        let ispCard = dashboardScreen.ispCard
        XCTAssertTrue(ispCard.waitForExistence(timeout: 5))
        
        // Should have "Internet" label
        XCTAssertTrue(
            app.staticTexts["Internet"].exists,
            "Internet card should show 'Internet' label"
        )
    }
    
    // MARK: - Local Devices Card Tests
    
    func testLocalDevicesCardDisplays() {
        dashboardScreen.swipeUp()
        
        XCTAssertTrue(
            dashboardScreen.localDevicesCard.waitForExistence(timeout: 5),
            "Local Devices card should be displayed"
        )
    }
    
    func testLocalDevicesCardShowsDeviceInfo() {
        dashboardScreen.swipeUp()
        
        let devicesCard = dashboardScreen.localDevicesCard
        XCTAssertTrue(devicesCard.waitForExistence(timeout: 5))
        
        // Should have "Local Devices" label
        XCTAssertTrue(
            app.staticTexts["Local Devices"].exists,
            "Local Devices card should show 'Local Devices' label"
        )
    }
    
    // MARK: - Settings Navigation Tests
    
    func testSettingsButtonExists() {
        XCTAssertTrue(
            dashboardScreen.settingsButton.waitForExistence(timeout: 5),
            "Settings button should exist in toolbar"
        )
    }
    
    func testSettingsButtonOpensSettings() {
        let settingsScreen = dashboardScreen.openSettings()
        
        XCTAssertTrue(
            settingsScreen.isDisplayed(),
            "Settings screen should open when tapping settings button"
        )
    }
    
    // MARK: - All Cards Present Test
    
    func testAllDashboardCardsPresent() {
        // Start with cards visible at top
        XCTAssertTrue(dashboardScreen.connectionStatusHeader.waitForExistence(timeout: 5))
        XCTAssertTrue(dashboardScreen.sessionCard.waitForExistence(timeout: 5))
        XCTAssertTrue(dashboardScreen.wifiCard.waitForExistence(timeout: 5))
        XCTAssertTrue(dashboardScreen.gatewayCard.waitForExistence(timeout: 5))
        
        // Scroll to see remaining cards
        dashboardScreen.swipeUp()
        
        XCTAssertTrue(dashboardScreen.ispCard.waitForExistence(timeout: 5))
        XCTAssertTrue(dashboardScreen.localDevicesCard.waitForExistence(timeout: 5))
    }
    
    // MARK: - Pull to Refresh Test
    
    func testPullToRefreshWorks() {
        // Swipe down on dashboard to trigger refresh
        dashboardScreen.swipeDown()
        
        // Dashboard should still be displayed after refresh
        XCTAssertTrue(
            dashboardScreen.isDisplayed(),
            "Dashboard should remain displayed after pull to refresh"
        )
    }
    
    // MARK: - Tab Navigation Tests
    
    func testCanNavigateToToolsAndBack() {
        // Navigate to Tools
        dashboardScreen.navigateToTab("Tools")
        
        let toolsScreen = app.otherElements["screen_tools"]
        XCTAssertTrue(toolsScreen.waitForExistence(timeout: 5), "Should navigate to Tools")
        
        // Navigate back to Dashboard
        dashboardScreen.navigateToTab("Dashboard")
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to Dashboard")
    }
    
    func testCanNavigateToMapAndBack() {
        // Navigate to Map
        dashboardScreen.navigateToTab("Map")
        
        let mapScreen = app.otherElements["screen_networkMap"]
        XCTAssertTrue(mapScreen.waitForExistence(timeout: 5), "Should navigate to Map")
        
        // Navigate back to Dashboard
        dashboardScreen.navigateToTab("Dashboard")
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to Dashboard")
    }
}
