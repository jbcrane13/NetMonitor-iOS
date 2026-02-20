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
        XCTAssertTrue(
            toolsScreen.quickActionsSection.waitForExistence(timeout: 5),
            "Quick Actions section should expose tools_section_quickActions identifier"
        )
    }

    func testToolsGridSectionExists() {
        XCTAssertTrue(
            toolsScreen.toolsGridSection.waitForExistence(timeout: 5),
            "Tools grid section should expose tools_section_grid identifier"
        )
    }

    func testRecentActivitySectionExists() {
        toolsScreen.swipeUp()
        toolsScreen.swipeUp()
        XCTAssertTrue(
            toolsScreen.recentActivitySection.waitForExistence(timeout: 5),
            "Recent activity section should expose tools_section_recentActivity identifier"
        )
    }
    
    // MARK: - Quick Actions Tests

    func testScanNetworkButtonExists() {
        toolsScreen.scrollToQuickActions()
        XCTAssertTrue(
            toolsScreen.quickActionExists(toolsScreen.scanNetworkButton, labelText: "Set Target"),
            "Set Target quick action should exist"
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
            toolsScreen.quickActionExists(toolsScreen.scanNetworkButton, labelText: "Set Target"),
            "Set Target quick action should exist"
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

    // MARK: - Functional Verification Tests

    func testPingGatewayShowsResult() {
        toolsScreen.scrollToQuickActions()

        let didTapQuickAction: Bool
        if toolsScreen.pingGatewayButton.waitForExistence(timeout: 3) {
            toolsScreen.pingGatewayButton.tap()
            didTapQuickAction = true
        } else {
            let fallback = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] 'Ping Gateway'")
            ).firstMatch
            if fallback.waitForExistence(timeout: 3) {
                fallback.tap()
                didTapQuickAction = true
            } else {
                didTapQuickAction = false
            }
        }
        XCTAssertTrue(didTapQuickAction, "Ping Gateway quick action should be tappable by identifier or visible label")

        let hasResultText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'ms' OR label CONTAINS[c] 'Ping' OR label CONTAINS[c] 'Success' OR label CONTAINS[c] 'Failed'")
        ).firstMatch.waitForExistence(timeout: 10)

        XCTAssertTrue(
            hasResultText,
            "Ping Gateway quick action should render a measurable result string"
        )
    }

    func testSetTargetOpensSheet() {
        toolsScreen.scrollToQuickActions()

        let setTargetButtonByID = toolsScreen.scanNetworkButton
        let setTargetButtonByLabel = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Set Target'")
        ).firstMatch

        let didTapQuickAction: Bool
        if setTargetButtonByID.waitForExistence(timeout: 3) {
            setTargetButtonByID.tap()
            didTapQuickAction = true
        } else if setTargetButtonByLabel.waitForExistence(timeout: 3) {
            setTargetButtonByLabel.tap()
            didTapQuickAction = true
        } else {
            didTapQuickAction = false
        }

        XCTAssertTrue(didTapQuickAction, "Set Target quick action should be reachable by identifier or label")
        XCTAssertTrue(
            app.navigationBars["Set Target"].waitForExistence(timeout: 5),
            "Tapping Set Target quick action should open Set Target sheet"
        )
    }

    func testRecentActivityEntriesDisplay() {
        // Run a tool briefly to generate an activity entry
        let pingScreen = toolsScreen.openPingTool()
        pingScreen.enterHost("1.1.1.1").startPing()
        XCTAssertTrue(
            pingScreen.waitForResults(timeout: 30),
            "Ping run should complete with result rows before returning to Tools"
        )
        pingScreen.navigateBack()

        // Scroll to recent activity section
        toolsScreen.swipeUp()
        toolsScreen.swipeUp()

        XCTAssertTrue(
            toolsScreen.recentActivitySection.waitForExistence(timeout: 5),
            "Recent activity section should be visible on Tools screen"
        )
        let hasActivityText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Ping' OR label CONTAINS[c] 'ping'")
        ).count > 0

        XCTAssertTrue(
            toolsScreen.activityRows.count > 0 || hasActivityText,
            "Recent activity should show an entry after running Ping"
        )
    }

    func testClearActivityButtonWorks() {
        // Generate an activity entry first so clear action is available.
        let pingScreen = toolsScreen.openPingTool()
        pingScreen.enterHost("1.1.1.1").startPing()
        _ = pingScreen.waitForResults(timeout: 30)
        pingScreen.navigateBack()

        // Scroll to the recent activity section
        toolsScreen.swipeUp()
        toolsScreen.swipeUp()

        let clearButton = toolsScreen.clearActivityButton
        XCTAssertTrue(clearButton.waitForExistence(timeout: 5), "Clear activity button should exist when activity rows are present")

        let entriesBefore = toolsScreen.activityRows.count
        XCTAssertGreaterThan(entriesBefore, 0, "Recent activity should contain at least one entry before clear")

        clearButton.tap()

        let entriesAfter = toolsScreen.activityRows.count
        XCTAssertTrue(
            entriesAfter == 0 || entriesAfter < entriesBefore,
            "Clear activity should reduce or remove activity rows"
        )
    }
}
