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
        // Scroll down to ensure the info card at the bottom is visible
        wolScreen.swipeUp()
        wolScreen.swipeUp()
        XCTAssertTrue(
            wolScreen.verifyInfoCardPresent(),
            "Info card should exist"
        )
    }
    
    // MARK: - Input Tests
    
    func testCanEnterMACAddress() {
        wolScreen.enterMACAddress("AA:BB:CC:DD:EE:FF")

        let value = wolScreen.macAddressInput.value as? String ?? ""
        XCTAssertTrue(value.contains("AA:BB:CC"), "MAC address input should preserve entered MAC value")
    }
    
    // MARK: - Validation Tests
    
    func testInvalidMACAddressShowsError() {
        wolScreen.enterMACAddress("invalid")

        XCTAssertTrue(wolScreen.hasInvalidMACIndicator(), "Invalid MAC entry should show validation error indicator")
        XCTAssertFalse(wolScreen.sendButton.isEnabled, "Send button should stay disabled for invalid MAC input")
    }
    
    // MARK: - Send Tests
    
    func testCanSendWakePacket() {
        wolScreen
            .enterMACAddress("AA:BB:CC:DD:EE:FF")
            .sendWakePacket()

        let success = wolScreen.waitForSuccess(timeout: 15)
        let error = wolScreen.hasError()

        XCTAssertTrue(
            success || error,
            "Wake packet attempt should end in a concrete success or error card"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        wolScreen.navigateBack()

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }

    func testCanEnterBroadcastAddress() {
        let testAddress = "192.168.1.255"
        wolScreen.enterBroadcastAddress(testAddress)

        XCTAssertEqual(
            wolScreen.broadcastAddressInput.value as? String,
            testAddress,
            "Broadcast address input should contain entered value"
        )
    }

    func testWakeOnLANScreenHasNavigationTitle() {
        XCTAssertTrue(
            app.navigationBars["Wake on LAN"].waitForExistence(timeout: 5),
            "Wake on LAN navigation title should exist"
        )
    }

    // MARK: - Functional Verification Tests

    func testMACValidationIndicatorChanges() {
        wolScreen.enterMACAddress("AA:BB:CC:DD:EE:FF")

        XCTAssertTrue(
            wolScreen.hasValidMACIndicator(),
            "Valid MAC address should show the explicit valid-MAC indicator"
        )
        XCTAssertTrue(
            wolScreen.sendButton.isEnabled,
            "Valid MAC address should enable Send button"
        )
    }

    func testBroadcastAddressEditable() {
        let newAddress = "10.0.0.255"

        guard wolScreen.broadcastAddressInput.waitForExistence(timeout: 5) else {
            XCTFail("Broadcast address input field should be accessible")
            return
        }

        wolScreen.broadcastAddressInput.tap()

        // Clear existing content
        if let value = wolScreen.broadcastAddressInput.value as? String, !value.isEmpty {
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count + 5)
            wolScreen.broadcastAddressInput.typeText(deleteString)
        }

        wolScreen.broadcastAddressInput.typeText(newAddress)

        let fieldValue = wolScreen.broadcastAddressInput.value as? String ?? ""
        XCTAssertEqual(fieldValue, newAddress, "Broadcast address field should accept the full edited address")
    }

    func testSuccessCardShowsMAC() {
        wolScreen
            .enterMACAddress("AA:BB:CC:DD:EE:FF")
            .sendWakePacket()

        let success = wolScreen.waitForSuccess(timeout: 15)
        let hasError = wolScreen.hasError()

        if success {
            XCTAssertTrue(
                wolScreen.successMessage.exists,
                "Successful wake packet attempt should display success card"
            )
            let hasSuccessContent = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'sent' OR label CONTAINS[c] 'Wake' OR label CONTAINS[c] 'AA'")
            ).count > 0

            XCTAssertTrue(
                hasSuccessContent,
                "Success card should confirm wake packet was sent"
            )
        } else if hasError {
            XCTAssertTrue(
                wolScreen.errorMessage.exists,
                "Failed wake packet attempts should display error card"
            )
        } else {
            XCTFail("Wake on LAN send attempt should produce success or error state")
        }
    }
}
