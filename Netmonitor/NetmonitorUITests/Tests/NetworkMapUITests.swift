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
    
    func testMapTabExists() {
        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5), "Map tab should exist")
    }
    
    // MARK: - Topology Tests
    
    func testTopologyViewExists() {
        XCTAssertTrue(
            mapScreen.verifyTopologyPresent(),
            "Topology view should be present"
        )
    }
    
    func testGatewayNodeDisplays() {
        XCTAssertTrue(
            mapScreen.verifyGatewayNodePresent(),
            "Gateway node should be displayed in topology"
        )
    }
    
    // MARK: - Device List Tests
    
    func testDeviceListDisplays() {
        XCTAssertTrue(
            mapScreen.verifyDeviceListPresent(),
            "Device list section should be displayed"
        )
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
        
        // After scan, the map should still be displayed
        XCTAssertTrue(
            mapScreen.isDisplayed(),
            "Network Map should remain displayed after starting scan"
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

    func testScanButtonIsEnabled() {
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
}
