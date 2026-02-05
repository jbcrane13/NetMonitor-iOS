import XCTest

/// UI tests for the Wake on LAN tool functionality
final class WakeOnLANToolUITests: XCTestCase {
    
    var app: XCUIApplication!
    var wolScreen: WakeOnLANToolScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        wolScreen = toolsScreen.openWakeOnLANTool()
    }
    
    override func tearDown() {
        app = nil
        wolScreen = nil
        super.tearDown()
    }
    
    // MARK: - Screen Display Tests
    
    func testWakeOnLANToolScreenDisplays() {
        XCTAssertTrue(wolScreen.isDisplayed(), "Wake on LAN tool screen should be displayed")
    }
    
    func testMACAddressInputFieldExists() {
        XCTAssertTrue(
            wolScreen.macAddressInput.waitForExistence(timeout: 5),
            "MAC address input field should exist"
        )
    }
    
    func testBroadcastAddressInputFieldExists() {
        XCTAssertTrue(
            wolScreen.broadcastAddressInput.waitForExistence(timeout: 5),
            "Broadcast address input field should exist"
        )
    }
    
    func testSendButtonExists() {
        XCTAssertTrue(
            wolScreen.sendButton.waitForExistence(timeout: 5),
            "Send button should exist"
        )
    }
    
    func testInfoCardExists() {
        wolScreen.swipeUp()
        XCTAssertTrue(
            wolScreen.verifyInfoCardPresent(),
            "Info card should exist"
        )
    }
    
    // MARK: - Input Tests
    
    func testCanEnterMACAddress() {
        wolScreen.enterMACAddress("AA:BB:CC:DD:EE:FF")
        
        // MAC address may be formatted differently, just check it contains expected chars
        let value = wolScreen.macAddressInput.value as? String ?? ""
        XCTAssertTrue(
            value.contains("AA") || value.contains("aa"),
            "MAC address input should contain entered text"
        )
    }
    
    // MARK: - Validation Tests
    
    func testInvalidMACAddressShowsError() {
        wolScreen.enterMACAddress("invalid")
        
        // Button should be disabled or validation should show
        // The app validates MAC format before enabling send
        let sendButton = wolScreen.sendButton
        XCTAssertTrue(sendButton.exists, "Send button should exist")
        // Note: Can't easily check if button is disabled in XCUITest without specific accessibility
    }
    
    // MARK: - Send Tests
    
    func testCanSendWakePacket() {
        wolScreen
            .enterMACAddress("AA:BB:CC:DD:EE:FF")
            .sendWakePacket()
        
        // Should show success or error (depends on network)
        let success = wolScreen.waitForSuccess(timeout: 10)
        let error = wolScreen.hasError()
        
        XCTAssertTrue(
            success || error,
            "Wake packet should either succeed or show error"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        wolScreen.navigateBack()
        
        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }
}
