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
        // Connection status header may render as otherElements or contain known text
        let headerFound = dashboardScreen.connectionStatusHeader.waitForExistence(timeout: 5)
        let standaloneText = app.staticTexts["Standalone Mode"].waitForExistence(timeout: 3)
        XCTAssertTrue(
            headerFound || standaloneText,
            "Connection status header should be displayed"
        )
    }
    
    // MARK: - Session Card Tests
    
    func testSessionCardDisplays() {
        XCTAssertTrue(
            dashboardScreen.sessionCard.waitForExistence(timeout: 5) ||
            dashboardScreen.sessionCardText.waitForExistence(timeout: 3),
            "Session card should be displayed"
        )
    }
    
    func testSessionCardShowsSessionInfo() {
        // Session card should exist (either as otherElement or via text fallback)
        let cardExists = dashboardScreen.sessionCard.waitForExistence(timeout: 5) ||
            dashboardScreen.sessionCardText.waitForExistence(timeout: 3)
        XCTAssertTrue(cardExists, "Session card should exist")

        // Session card should contain session-related content
        let hasSessionLabel = app.staticTexts["Session"].exists
        let hasStartedLabel = app.staticTexts["Started"].exists
        let hasDurationLabel = app.staticTexts["Duration"].exists
        XCTAssertTrue(
            hasSessionLabel || hasStartedLabel || hasDurationLabel,
            "Session card should show session-related content"
        )
    }
    
    // MARK: - WiFi/Connection Card Tests
    
    func testWiFiCardDisplays() {
        XCTAssertTrue(
            dashboardScreen.wifiCard.waitForExistence(timeout: 5) ||
            dashboardScreen.connectionCardText.waitForExistence(timeout: 3),
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
            dashboardScreen.gatewayCard.waitForExistence(timeout: 5) ||
            dashboardScreen.gatewayCardText.waitForExistence(timeout: 3),
            "Gateway card should be displayed"
        )
    }
    
    func testGatewayCardShowsGatewayInfo() {
        // Gateway card should exist (either as otherElement or via text fallback)
        let cardExists = dashboardScreen.gatewayCard.waitForExistence(timeout: 5) ||
            dashboardScreen.gatewayCardText.waitForExistence(timeout: 3)
        XCTAssertTrue(cardExists, "Gateway card should exist")

        // Gateway card should contain gateway-related content
        let hasGatewayLabel = app.staticTexts["Gateway"].exists
        let hasDetecting = app.staticTexts["Detecting gateway..."].exists
        let hasIPLabel = app.staticTexts["IP Address"].exists
        XCTAssertTrue(
            hasGatewayLabel || hasDetecting || hasIPLabel,
            "Gateway card should show gateway-related content"
        )
    }
    
    // MARK: - ISP/Internet Card Tests
    
    func testISPCardDisplays() {
        // May need to scroll to see this card
        dashboardScreen.swipeUp()

        XCTAssertTrue(
            dashboardScreen.ispCard.waitForExistence(timeout: 5) ||
            dashboardScreen.internetCardText.waitForExistence(timeout: 3),
            "ISP/Internet card should be displayed"
        )
    }
    
    func testInternetCardShowsInternetInfo() {
        dashboardScreen.swipeUp()

        // Internet card should exist (either as otherElement or via text fallback)
        let cardExists = dashboardScreen.ispCard.waitForExistence(timeout: 5) ||
            dashboardScreen.internetCardText.waitForExistence(timeout: 3)
        XCTAssertTrue(cardExists, "Internet card should exist")

        // Internet card should contain internet-related content
        let hasInternetLabel = app.staticTexts["Internet"].exists
        let hasFetching = app.staticTexts["Fetching public IP..."].exists
        let hasPublicIP = app.staticTexts["Public IP"].exists
        XCTAssertTrue(
            hasInternetLabel || hasFetching || hasPublicIP,
            "Internet card should show internet-related content"
        )
    }
    
    // MARK: - Local Devices Card Tests
    
    func testLocalDevicesCardDisplays() {
        dashboardScreen.swipeUp()

        XCTAssertTrue(
            dashboardScreen.localDevicesCard.waitForExistence(timeout: 5) ||
            dashboardScreen.localDevicesCardText.waitForExistence(timeout: 3),
            "Local Devices card should be displayed"
        )
    }
    
    func testLocalDevicesCardShowsDeviceInfo() {
        dashboardScreen.swipeUp()

        // Local Devices card should exist (either as otherElement or via text fallback)
        let cardExists = dashboardScreen.localDevicesCard.waitForExistence(timeout: 5) ||
            dashboardScreen.localDevicesCardText.waitForExistence(timeout: 3)
        XCTAssertTrue(cardExists, "Local Devices card should exist")

        // Local Devices card should contain device-related content
        let hasDevicesLabel = app.staticTexts["Local Devices"].exists
        let hasLastScan = app.staticTexts["Last Scan"].exists
        let hasDevicesCount = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'devices'")).count > 0
        XCTAssertTrue(
            hasDevicesLabel || hasLastScan || hasDevicesCount,
            "Local Devices card should show device-related content"
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
        // Start with cards visible at top - use fallback text checks for reliability
        XCTAssertTrue(
            dashboardScreen.connectionStatusHeader.waitForExistence(timeout: 5) ||
            app.staticTexts["Standalone Mode"].exists
        )
        XCTAssertTrue(
            dashboardScreen.sessionCard.waitForExistence(timeout: 5) ||
            dashboardScreen.sessionCardText.exists
        )
        XCTAssertTrue(
            dashboardScreen.wifiCard.waitForExistence(timeout: 5) ||
            dashboardScreen.connectionCardText.exists
        )
        XCTAssertTrue(
            dashboardScreen.gatewayCard.waitForExistence(timeout: 5) ||
            dashboardScreen.gatewayCardText.exists
        )

        // Scroll to see remaining cards
        dashboardScreen.swipeUp()

        XCTAssertTrue(
            dashboardScreen.ispCard.waitForExistence(timeout: 5) ||
            dashboardScreen.internetCardText.exists
        )
        XCTAssertTrue(
            dashboardScreen.localDevicesCard.waitForExistence(timeout: 5) ||
            dashboardScreen.localDevicesCardText.exists
        )
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

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should navigate to Tools")

        // Navigate back to Dashboard
        dashboardScreen.navigateToTab("Dashboard")
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to Dashboard")
    }
    
    func testCanNavigateToMapAndBack() {
        // Navigate to Map
        dashboardScreen.navigateToTab("Map")

        let mapScreen = NetworkMapScreen(app: app)
        XCTAssertTrue(mapScreen.isDisplayed(), "Should navigate to Map")

        // Navigate back to Dashboard
        dashboardScreen.navigateToTab("Dashboard")
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to Dashboard")
    }
}
