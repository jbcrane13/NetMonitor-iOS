import XCTest

/// Tools screen page object
final class ToolsScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_tools"]
    }
    
    // MARK: - Sections
    var quickActionsSection: XCUIElement {
        app.otherElements["tools_section_quickActions"]
    }
    
    var toolsGridSection: XCUIElement {
        app.otherElements["tools_section_grid"]
    }
    
    var recentActivitySection: XCUIElement {
        app.otherElements["tools_section_recentActivity"]
    }
    
    // MARK: - Quick Action Buttons
    var scanNetworkButton: XCUIElement {
        app.buttons["quickAction_scan_network"]
    }
    
    var speedTestQuickButton: XCUIElement {
        app.buttons["quickAction_speed_test"]
    }
    
    var pingGatewayButton: XCUIElement {
        app.buttons["quickAction_ping_gateway"]
    }
    
    // MARK: - Tool Cards
    var pingToolCard: XCUIElement {
        app.buttons["tools_card_ping"]
    }
    
    var tracerouteToolCard: XCUIElement {
        app.buttons["tools_card_traceroute"]
    }
    
    var dnsLookupToolCard: XCUIElement {
        app.buttons["tools_card_dns_lookup"]
    }
    
    var portScannerToolCard: XCUIElement {
        app.buttons["tools_card_port_scanner"]
    }
    
    var bonjourToolCard: XCUIElement {
        app.buttons["tools_card_bonjour"]
    }
    
    var speedTestToolCard: XCUIElement {
        app.buttons["tools_card_speed_test"]
    }
    
    var whoisToolCard: XCUIElement {
        app.buttons["tools_card_whois"]
    }
    
    var wakeOnLANToolCard: XCUIElement {
        app.buttons["tools_card_wake_on_lan"]
    }
    
    // MARK: - Activity
    var clearActivityButton: XCUIElement {
        app.buttons["tools_button_clearActivity"]
    }
    
    // MARK: - Navigation
    @discardableResult
    func navigateToTools() -> Self {
        navigateToTab("Tools")
        _ = waitForElement(screen)
        return self
    }
    
    @discardableResult
    func openPingTool() -> PingToolScreen {
        tapIfExists(pingToolCard)
        return PingToolScreen(app: app)
    }
    
    @discardableResult
    func openTracerouteTool() -> TracerouteToolScreen {
        tapIfExists(tracerouteToolCard)
        return TracerouteToolScreen(app: app)
    }
    
    @discardableResult
    func openDNSLookupTool() -> DNSLookupToolScreen {
        tapIfExists(dnsLookupToolCard)
        return DNSLookupToolScreen(app: app)
    }
    
    @discardableResult
    func openPortScannerTool() -> PortScannerToolScreen {
        tapIfExists(portScannerToolCard)
        return PortScannerToolScreen(app: app)
    }
    
    @discardableResult
    func openBonjourTool() -> BonjourToolScreen {
        tapIfExists(bonjourToolCard)
        return BonjourToolScreen(app: app)
    }
    
    @discardableResult
    func openSpeedTestTool() -> SpeedTestToolScreen {
        tapIfExists(speedTestToolCard)
        return SpeedTestToolScreen(app: app)
    }
    
    @discardableResult
    func openWHOISTool() -> WHOISToolScreen {
        tapIfExists(whoisToolCard)
        return WHOISToolScreen(app: app)
    }
    
    @discardableResult
    func openWakeOnLANTool() -> WakeOnLANToolScreen {
        tapIfExists(wakeOnLANToolCard)
        return WakeOnLANToolScreen(app: app)
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        waitForElement(screen)
    }
    
    func verifyAllToolsPresent() -> Bool {
        waitForElement(pingToolCard) &&
        waitForElement(tracerouteToolCard) &&
        waitForElement(dnsLookupToolCard) &&
        waitForElement(portScannerToolCard) &&
        waitForElement(bonjourToolCard) &&
        waitForElement(speedTestToolCard) &&
        waitForElement(whoisToolCard) &&
        waitForElement(wakeOnLANToolCard)
    }
    
    func verifyQuickActionsPresent() -> Bool {
        waitForElement(quickActionsSection) &&
        waitForElement(scanNetworkButton) &&
        waitForElement(speedTestQuickButton) &&
        waitForElement(pingGatewayButton)
    }
}
