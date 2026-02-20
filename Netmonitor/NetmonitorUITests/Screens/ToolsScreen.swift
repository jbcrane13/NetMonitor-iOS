import XCTest

/// Tools screen page object
final class ToolsScreen: BaseScreen {

    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_tools"]
    }

    // MARK: - Sections
    var quickActionsSection: XCUIElement {
        app.descendants(matching: .any)["tools_section_quickActions"]
    }

    var toolsGridSection: XCUIElement {
        app.descendants(matching: .any)["tools_section_grid"]
    }

    var recentActivitySection: XCUIElement {
        app.descendants(matching: .any)["tools_section_recentActivity"]
    }

    // Header fallbacks if section containers are not exposed as hittable elements.
    var quickActionsSectionHeader: XCUIElement {
        app.staticTexts["Quick Actions"]
    }

    var toolsGridSectionHeader: XCUIElement {
        app.staticTexts["Network Tools"]
    }

    var recentActivitySectionHeader: XCUIElement {
        app.staticTexts["Recent Activity"]
    }

    // MARK: - Quick Action Buttons
    var scanNetworkButton: XCUIElement {
        app.descendants(matching: .any)["quickAction_set_target"]
    }

    var speedTestQuickButton: XCUIElement {
        app.descendants(matching: .any)["quickAction_speed_test"]
    }

    var pingGatewayButton: XCUIElement {
        app.descendants(matching: .any)["quickAction_ping_gateway"]
    }

    /// Check if a quick action button exists (by ID or label text fallback)
    func quickActionExists(_ button: XCUIElement, labelText: String) -> Bool {
        if button.waitForExistence(timeout: 3) {
            return true
        }
        // Fallback: find button containing the label text
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", labelText)
        return app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: 3)
    }
    
    // MARK: - Tool Cards
    var pingToolCard: XCUIElement {
        app.descendants(matching: .any)["tools_card_ping"]
    }
    
    var tracerouteToolCard: XCUIElement {
        app.descendants(matching: .any)["tools_card_traceroute"]
    }
    
    var dnsLookupToolCard: XCUIElement {
        app.descendants(matching: .any)["tools_card_dns_lookup"]
    }
    
    var portScannerToolCard: XCUIElement {
        app.descendants(matching: .any)["tools_card_port_scanner"]
    }
    
    var bonjourToolCard: XCUIElement {
        app.descendants(matching: .any)["tools_card_bonjour"]
    }
    
    var speedTestToolCard: XCUIElement {
        app.descendants(matching: .any)["tools_card_speed_test"]
    }
    
    var whoisToolCard: XCUIElement {
        app.descendants(matching: .any)["tools_card_whois"]
    }
    
    var wakeOnLANToolCard: XCUIElement {
        app.descendants(matching: .any)["tools_card_wake_on_lan"]
    }

    var webBrowserToolCard: XCUIElement {
        app.descendants(matching: .any)["tools_card_web_browser"]
    }

    // MARK: - Activity
    var clearActivityButton: XCUIElement {
        app.buttons["tools_button_clearActivity"]
    }

    var activityRows: XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'activityRow_'")
        )
    }

    // MARK: - Navigation
    @discardableResult
    func navigateToTools() -> Self {
        navigateToTab("Tools")
        // Wait for a reliable tool card button instead of screen container
        _ = waitForElement(pingToolCard)
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

    @discardableResult
    func openWebBrowserTool() -> WebBrowserToolScreen {
        tapIfExists(webBrowserToolCard)
        return WebBrowserToolScreen(app: app)
    }

    // MARK: - Scrolling
    /// Scroll to top to ensure quick actions are visible
    @discardableResult
    func scrollToQuickActions() -> Self {
        scrollToTop()
        return self
    }

    // MARK: - Verification
    func isDisplayed() -> Bool {
        // Check for a reliable tool card button instead of screen container
        // Buttons become available faster than otherElements during navigation
        waitForElement(pingToolCard)
    }

    func verifyAllToolsPresent() -> Bool {
        waitForElement(pingToolCard) &&
        waitForElement(tracerouteToolCard) &&
        waitForElement(dnsLookupToolCard) &&
        waitForElement(portScannerToolCard) &&
        waitForElement(bonjourToolCard) &&
        waitForElement(speedTestToolCard) &&
        waitForElement(whoisToolCard) &&
        waitForElement(wakeOnLANToolCard) &&
        waitForElement(webBrowserToolCard)
    }

    func verifyQuickActionsPresent() -> Bool {
        scrollToTop()
        return quickActionExists(scanNetworkButton, labelText: "Set Target") &&
        quickActionExists(speedTestQuickButton, labelText: "Speed Test") &&
        quickActionExists(pingGatewayButton, labelText: "Ping Gateway")
    }
}
