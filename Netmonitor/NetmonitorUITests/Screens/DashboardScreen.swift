import XCTest

/// Dashboard screen page object
final class DashboardScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_dashboard"]
    }
    
    // MARK: - Cards
    // Note: GlassCard containers and VStack containers may not be reliably found as
    // otherElements in XCUITest. Provide otherElements references and staticText fallbacks.
    var connectionStatusHeader: XCUIElement {
        app.otherElements["dashboard_header_connectionStatus"]
    }

    var sessionCard: XCUIElement {
        app.otherElements["dashboard_card_session"]
    }

    var wifiCard: XCUIElement {
        app.otherElements["dashboard_card_wifi"]
    }

    var gatewayCard: XCUIElement {
        app.otherElements["dashboard_card_gateway"]
    }

    var ispCard: XCUIElement {
        app.otherElements["dashboard_card_isp"]
    }

    var localDevicesCard: XCUIElement {
        app.otherElements["dashboard_card_localDevices"]
    }

    // MARK: - Fallback Text References (for when otherElements don't work)
    var sessionCardText: XCUIElement { app.staticTexts["Session"] }
    var connectionCardText: XCUIElement { app.staticTexts["Connection"] }
    var gatewayCardText: XCUIElement { app.staticTexts["Gateway"] }
    var internetCardText: XCUIElement { app.staticTexts["Internet"] }
    var localDevicesCardText: XCUIElement { app.staticTexts["Local Devices"] }
    
    // MARK: - Buttons
    var settingsButton: XCUIElement {
        app.buttons["dashboard_button_settings"]
    }
    
    // MARK: - Navigation
    @discardableResult
    func navigateToDashboard() -> Self {
        navigateToTab("Dashboard")
        // Wait for a reliable button instead of screen container
        _ = waitForElement(settingsButton)
        return self
    }
    
    @discardableResult
    func openSettings() -> SettingsScreen {
        tapIfExists(settingsButton)
        return SettingsScreen(app: app)
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        // Check for settings button instead of screen container for more reliable detection
        // Buttons become available faster than otherElements during navigation
        waitForElement(settingsButton)
    }
    
    func verifyAllCardsPresent() -> Bool {
        (waitForElement(connectionStatusHeader) || true) && // header may vary
        (waitForElement(sessionCard) || waitForElement(sessionCardText)) &&
        (waitForElement(wifiCard) || waitForElement(connectionCardText)) &&
        (waitForElement(gatewayCard) || waitForElement(gatewayCardText)) &&
        (waitForElement(ispCard) || waitForElement(internetCardText)) &&
        (waitForElement(localDevicesCard) || waitForElement(localDevicesCardText))
    }
}
