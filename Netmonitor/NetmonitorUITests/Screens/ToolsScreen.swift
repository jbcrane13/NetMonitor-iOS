import XCTest

/// Tools screen page object
final class ToolsScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_tools"]
    }
    
    // MARK: - Sections
    // Note: SwiftUI containers with accessibilityIdentifier are unreliable as otherElements
    // in XCUITest. Use staticTexts section headers as proxy for section existence.
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
        app.buttons["quickAction_scan_network"]
    }

    var speedTestQuickButton: XCUIElement {
        app.buttons["quickAction_speed_test"]
    }

    var pingGatewayButton: XCUIElement {
        app.buttons["quickAction_ping_gateway"]
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
        waitForElement(wakeOnLANToolCard)
    }

    func verifyQuickActionsPresent() -> Bool {
        scrollToTop()
        return quickActionExists(scanNetworkButton, labelText: "Scan Network") &&
        quickActionExists(speedTestQuickButton, labelText: "Speed Test") &&
        quickActionExists(pingGatewayButton, labelText: "Ping Gateway")
    }
}
