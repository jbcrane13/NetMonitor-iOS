import XCTest

/// Comprehensive UI tests for the Tools screen and all network tools
final class ToolsUITests: XCTestCase {
    
    var app: XCUIApplication!
    var toolsScreen: ToolsScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
    }
    
    override func tearDown() {
        app = nil
        toolsScreen = nil
        super.tearDown()
    }
    
    // MARK: - Tools Screen Tests
    
    func testToolsScreenLoads() {
        XCTAssertTrue(toolsScreen.isDisplayed(), "Tools screen should load")
    }
    
    func testQuickActionsSectionExists() {
        // Verify quick actions section by checking for its header text and a known child button
        XCTAssertTrue(
            toolsScreen.quickActionsSectionHeader.waitForExistence(timeout: 5) ||
            toolsScreen.scanNetworkButton.waitForExistence(timeout: 5),
            "Quick Actions section should exist"
        )
    }

    func testToolsGridSectionExists() {
        // Verify tools grid section by checking for its header text and a known child card
        XCTAssertTrue(
            toolsScreen.toolsGridSectionHeader.waitForExistence(timeout: 5) ||
            toolsScreen.pingToolCard.waitForExistence(timeout: 5),
            "Tools grid section should exist"
        )
    }

    func testRecentActivitySectionExists() {
        // Scroll down to reveal recent activity section
        toolsScreen.swipeUp()
        toolsScreen.swipeUp()
        XCTAssertTrue(
            toolsScreen.recentActivitySectionHeader.waitForExistence(timeout: 5),
            "Recent activity section should exist"
        )
    }
    
    // MARK: - Quick Actions Tests

    func testScanNetworkButtonExists() {
        toolsScreen.scrollToQuickActions()
        XCTAssertTrue(
            toolsScreen.quickActionExists(toolsScreen.scanNetworkButton, labelText: "Scan Network"),
            "Scan Network quick action should exist"
        )
    }

    func testSpeedTestQuickButtonExists() {
        toolsScreen.scrollToQuickActions()
        XCTAssertTrue(
            toolsScreen.quickActionExists(toolsScreen.speedTestQuickButton, labelText: "Speed Test"),
            "Speed Test quick action should exist"
        )
    }

    func testPingGatewayButtonExists() {
        toolsScreen.scrollToQuickActions()
        XCTAssertTrue(
            toolsScreen.quickActionExists(toolsScreen.pingGatewayButton, labelText: "Ping Gateway"),
            "Ping Gateway quick action should exist"
        )
    }

    func testAllQuickActionsPresent() {
        XCTAssertTrue(toolsScreen.verifyQuickActionsPresent(), "All quick actions should be present")
    }
    
    // MARK: - Tool Cards Existence Tests

    func testAllNineToolsPresent() {
        XCTAssertTrue(toolsScreen.verifyAllToolsPresent(), "All 9 tools should be present")
    }
    
    func testPingToolCardExists() {
        XCTAssertTrue(
            toolsScreen.pingToolCard.waitForExistence(timeout: 5),
            "Ping tool card should exist"
        )
    }
    
    func testTracerouteToolCardExists() {
        XCTAssertTrue(
            toolsScreen.tracerouteToolCard.waitForExistence(timeout: 5),
            "Traceroute tool card should exist"
        )
    }
    
    func testDNSLookupToolCardExists() {
        XCTAssertTrue(
            toolsScreen.dnsLookupToolCard.waitForExistence(timeout: 5),
            "DNS Lookup tool card should exist"
        )
    }
    
    func testPortScannerToolCardExists() {
        XCTAssertTrue(
            toolsScreen.portScannerToolCard.waitForExistence(timeout: 5),
            "Port Scanner tool card should exist"
        )
    }
    
    func testBonjourToolCardExists() {
        XCTAssertTrue(
            toolsScreen.bonjourToolCard.waitForExistence(timeout: 5),
            "Bonjour tool card should exist"
        )
    }
    
    func testSpeedTestToolCardExists() {
        XCTAssertTrue(
            toolsScreen.speedTestToolCard.waitForExistence(timeout: 5),
            "Speed Test tool card should exist"
        )
    }
    
    func testWHOISToolCardExists() {
        XCTAssertTrue(
            toolsScreen.whoisToolCard.waitForExistence(timeout: 5),
            "WHOIS tool card should exist"
        )
    }
    
    func testWakeOnLANToolCardExists() {
        XCTAssertTrue(
            toolsScreen.wakeOnLANToolCard.waitForExistence(timeout: 5),
            "Wake on LAN tool card should exist"
        )
    }

    func testWebBrowserToolCardExists() {
        XCTAssertTrue(
            toolsScreen.webBrowserToolCard.waitForExistence(timeout: 5),
            "Web Browser tool card should exist"
        )
    }

    // MARK: - Tool Navigation Tests
    
    func testPingToolOpens() {
        let pingScreen = toolsScreen.openPingTool()
        XCTAssertTrue(pingScreen.isDisplayed(), "Ping tool screen should open")
    }
    
    func testTracerouteToolOpens() {
        let tracerouteScreen = toolsScreen.openTracerouteTool()
        XCTAssertTrue(tracerouteScreen.isDisplayed(), "Traceroute tool screen should open")
    }
    
    func testDNSLookupToolOpens() {
        let dnsScreen = toolsScreen.openDNSLookupTool()
        XCTAssertTrue(dnsScreen.isDisplayed(), "DNS Lookup tool screen should open")
    }
    
    func testPortScannerToolOpens() {
        let portScanScreen = toolsScreen.openPortScannerTool()
        XCTAssertTrue(portScanScreen.isDisplayed(), "Port Scanner tool screen should open")
    }
    
    func testBonjourToolOpens() {
        let bonjourScreen = toolsScreen.openBonjourTool()
        XCTAssertTrue(bonjourScreen.isDisplayed(), "Bonjour tool screen should open")
    }
    
    func testSpeedTestToolOpens() {
        let speedTestScreen = toolsScreen.openSpeedTestTool()
        XCTAssertTrue(speedTestScreen.isDisplayed(), "Speed Test tool screen should open")
    }
    
    func testWHOISToolOpens() {
        let whoisScreen = toolsScreen.openWHOISTool()
        XCTAssertTrue(whoisScreen.isDisplayed(), "WHOIS tool screen should open")
    }
    
    func testWakeOnLANToolOpens() {
        let wolScreen = toolsScreen.openWakeOnLANTool()
        XCTAssertTrue(wolScreen.isDisplayed(), "Wake on LAN tool screen should open")
    }

    func testWebBrowserToolOpens() {
        let webBrowserScreen = toolsScreen.openWebBrowserTool()
        XCTAssertTrue(webBrowserScreen.isDisplayed(), "Web Browser tool screen should open")
    }

    // MARK: - Quick Action Navigation Tests
    
    func testSpeedTestQuickActionOpensSpeedTest() {
        toolsScreen.scrollToQuickActions()
        // Try tapping by ID first, fall back to label text
        if toolsScreen.speedTestQuickButton.waitForExistence(timeout: 3) {
            toolsScreen.speedTestQuickButton.tap()
        } else {
            let predicate = NSPredicate(format: "label CONTAINS[c] %@", "Speed Test")
            let fallbackButton = app.buttons.matching(predicate).firstMatch
            if fallbackButton.waitForExistence(timeout: 3) {
                fallbackButton.tap()
            }
        }
        let speedTestScreen = SpeedTestToolScreen(app: app)
        XCTAssertTrue(speedTestScreen.isDisplayed(), "Speed Test quick action should open Speed Test tool")
    }

    func testScanNetworkQuickActionExists() {
        toolsScreen.scrollToQuickActions()
        XCTAssertTrue(
            toolsScreen.quickActionExists(toolsScreen.scanNetworkButton, labelText: "Scan Network"),
            "Scan Network quick action should exist"
        )
    }

    func testPingGatewayQuickActionExists() {
        toolsScreen.scrollToQuickActions()
        XCTAssertTrue(
            toolsScreen.quickActionExists(toolsScreen.pingGatewayButton, labelText: "Ping Gateway"),
            "Ping Gateway quick action should exist"
        )
    }

    func testCanScrollToolsView() {
        toolsScreen.swipeUp()
        toolsScreen.swipeDown()
        XCTAssertTrue(toolsScreen.isDisplayed(), "Tools screen should still be displayed after scrolling")
    }
}
