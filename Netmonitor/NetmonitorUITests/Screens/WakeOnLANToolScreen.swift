import XCTest

/// Wake on LAN Tool screen page object
final class WakeOnLANToolScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_wolTool"]
    }
    
    // MARK: - Input Elements
    var macAddressInput: XCUIElement {
        app.textFields["wol_input_mac"]
    }
    
    var broadcastAddressInput: XCUIElement {
        app.textFields["wol_input_broadcast"]
    }
    
    // MARK: - Control Buttons
    var sendButton: XCUIElement {
        app.buttons["wol_button_send"]
    }
    
    // MARK: - Results
    var successMessage: XCUIElement {
        app.otherElements["wol_success"]
    }
    
    var errorMessage: XCUIElement {
        app.otherElements["wol_error"]
    }
    
    var infoCard: XCUIElement {
        app.otherElements["wol_info"]
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        waitForElement(screen)
    }
    
    // MARK: - Actions
    @discardableResult
    func enterMACAddress(_ mac: String) -> Self {
        if macAddressInput.waitForExistence(timeout: timeout) {
            macAddressInput.tap()
            macAddressInput.typeText(mac)
        }
        return self
    }
    
    @discardableResult
    func enterBroadcastAddress(_ address: String) -> Self {
        if broadcastAddressInput.waitForExistence(timeout: timeout) {
            broadcastAddressInput.tap()
            // Clear existing text
            if let value = broadcastAddressInput.value as? String, !value.isEmpty {
                let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
                broadcastAddressInput.typeText(deleteString)
            }
            broadcastAddressInput.typeText(address)
        }
        return self
    }
    
    @discardableResult
    func sendWakePacket() -> Self {
        tapIfExists(sendButton)
        return self
    }
    
    func waitForSuccess(timeout: TimeInterval = 10) -> Bool {
        successMessage.waitForExistence(timeout: timeout)
    }
    
    func hasError() -> Bool {
        errorMessage.exists
    }
    
    func verifyInfoCardPresent() -> Bool {
        waitForElement(infoCard)
    }
    
    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
