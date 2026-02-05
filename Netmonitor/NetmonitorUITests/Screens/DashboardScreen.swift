import XCTest

/// Dashboard screen page object
final class DashboardScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_dashboard"]
    }
    
    // MARK: - Cards
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
    
    // MARK: - Buttons
    var settingsButton: XCUIElement {
        app.buttons["dashboard_button_settings"]
    }
    
    // MARK: - Navigation
    @discardableResult
    func navigateToDashboard() -> Self {
        navigateToTab("Dashboard")
        _ = waitForElement(screen)
        return self
    }
    
    @discardableResult
    func openSettings() -> SettingsScreen {
        tapIfExists(settingsButton)
        return SettingsScreen(app: app)
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        waitForElement(screen)
    }
    
    func verifyAllCardsPresent() -> Bool {
        waitForElement(connectionStatusHeader) &&
        waitForElement(sessionCard) &&
        waitForElement(wifiCard) &&
        waitForElement(gatewayCard) &&
        waitForElement(ispCard) &&
        waitForElement(localDevicesCard)
    }
}
