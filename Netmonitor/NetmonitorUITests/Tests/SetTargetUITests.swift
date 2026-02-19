import XCTest

/// Comprehensive UI tests for the Set Target flow
final class SetTargetUITests: XCTestCase {

    var app: XCUIApplication!
    var toolsScreen: ToolsScreen!
    var setTargetScreen: SetTargetScreen!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        toolsScreen = ToolsScreen(app: app)
        setTargetScreen = SetTargetScreen(app: app)
        toolsScreen.navigateToTools()
    }

    override func tearDown() {
        app = nil
        toolsScreen = nil
        setTargetScreen = nil
        super.tearDown()
    }

    // MARK: - Sheet Presentation Tests

    func testSetTargetButtonOnToolsTabOpensSheet() {
        XCTAssertTrue(
            setTargetScreen.setTargetQuickActionButton.waitForExistence(timeout: 5),
            "Set Target quick action button should exist on Tools tab"
        )
        setTargetScreen.openSheet()
        XCTAssertTrue(
            setTargetScreen.isSheetDisplayed(),
            "Set Target sheet should open after tapping the quick action button"
        )
    }

    // MARK: - Input Tests

    func testCanEnterTargetAddressInTextField() {
        setTargetScreen.openSheet()
        XCTAssertTrue(
            setTargetScreen.addressInput.waitForExistence(timeout: 5),
            "Address text field should exist in Set Target sheet"
        )
        setTargetScreen.enterAddress("example.com")
        XCTAssertEqual(
            setTargetScreen.addressInput.value as? String,
            "example.com",
            "Address field should contain the entered text"
        )
    }

    func testSetButtonAppearanceAfterTyping() {
        setTargetScreen.openSheet()
        // Set button only appears when text is non-empty
        XCTAssertFalse(
            setTargetScreen.setButton.exists,
            "Set button should not appear when address field is empty"
        )
        setTargetScreen.enterAddress("192.168.1.1")
        XCTAssertTrue(
            setTargetScreen.setButton.waitForExistence(timeout: 5),
            "Set button should appear after entering text"
        )
    }

    // MARK: - Set Target Tests

    func testSetButtonSavesTargetAndDismissesSheet() {
        setTargetScreen.openSheet()
        setTargetScreen.enterAddress("192.168.1.1")
        XCTAssertTrue(
            setTargetScreen.setButton.waitForExistence(timeout: 5),
            "Set button should appear after entering text"
        )
        setTargetScreen.tapSet()
        XCTAssertFalse(
            setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 5),
            "Sheet should be dismissed after tapping Set"
        )
    }

    func testActiveTargetIsDisplayedOnQuickActionButtonAfterSetting() {
        setTargetScreen.openSheet()
        setTargetScreen.enterAddress("192.168.1.100")
        setTargetScreen.tapSet()
        // Wait for sheet to dismiss
        _ = !setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 3)
        // The quick action button label should now contain the target address
        XCTAssertTrue(
            setTargetScreen.setTargetQuickActionButton.waitForExistence(timeout: 5),
            "Quick action button should exist after setting target"
        )
        let buttonLabel = setTargetScreen.setTargetQuickActionButton.label
        XCTAssertTrue(
            buttonLabel.contains("192.168.1.100"),
            "Quick action button should display active target address, got: \(buttonLabel)"
        )
    }

    // MARK: - Clear Target Tests

    func testClearButtonRemovesActiveTarget() {
        // First set a target
        setTargetScreen.openSheet()
        setTargetScreen.enterAddress("10.0.0.1")
        setTargetScreen.tapSet()
        _ = !setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 3)

        // Reopen the sheet
        setTargetScreen.openSheet()
        XCTAssertTrue(
            setTargetScreen.activeTargetHeader.waitForExistence(timeout: 5),
            "Active Target section should be visible when a target is set"
        )
        XCTAssertTrue(
            setTargetScreen.clearButton.waitForExistence(timeout: 5),
            "Clear button should exist when an active target is set"
        )
        setTargetScreen.tapClear()

        // Active Target section should disappear after clearing
        XCTAssertFalse(
            setTargetScreen.activeTargetHeader.waitForExistence(timeout: 3),
            "Active Target section should disappear after clearing"
        )
    }

    // MARK: - Saved Targets Tests

    func testSavedTargetsListDisplaysPreviouslySetTargets() {
        // Set a target to create a saved entry
        setTargetScreen.openSheet()
        setTargetScreen.enterAddress("saved.example.com")
        setTargetScreen.tapSet()
        _ = !setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 3)

        // Reopen the sheet and verify saved targets section
        setTargetScreen.openSheet()
        XCTAssertTrue(
            setTargetScreen.savedTargetsHeader.waitForExistence(timeout: 5),
            "Saved Targets section header should be visible after setting a target"
        )
        XCTAssertTrue(
            setTargetScreen.savedTargetRow(for: "saved.example.com").waitForExistence(timeout: 5),
            "Previously set target should appear in the Saved Targets list"
        )
    }

    func testTappingSavedTargetSelectsItAndDismissesSheet() {
        // Set a target to populate saved list
        setTargetScreen.openSheet()
        setTargetScreen.enterAddress("tap.example.com")
        setTargetScreen.tapSet()
        _ = !setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 3)

        // Clear the current target, then reopen
        setTargetScreen.openSheet()
        if setTargetScreen.clearButton.waitForExistence(timeout: 3) {
            setTargetScreen.tapClear()
        }
        setTargetScreen.tapCancel()
        _ = !setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 3)

        // Reopen and tap the saved target row
        setTargetScreen.openSheet()
        let savedRow = setTargetScreen.savedTargetRow(for: "tap.example.com")
        XCTAssertTrue(savedRow.waitForExistence(timeout: 5), "Saved target row should exist")
        savedRow.tap()

        // Sheet should dismiss after tapping a saved target
        XCTAssertFalse(
            setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 5),
            "Sheet should dismiss after tapping a saved target"
        )
        // Quick action button should now show the selected target
        let buttonLabel = setTargetScreen.setTargetQuickActionButton.label
        XCTAssertTrue(
            buttonLabel.contains("tap.example.com"),
            "Quick action button should show the selected saved target"
        )
    }

    func testSwipeToDeleteRemovesSavedTarget() {
        // Set a target to populate saved list
        setTargetScreen.openSheet()
        setTargetScreen.enterAddress("delete.example.com")
        setTargetScreen.tapSet()
        _ = !setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 3)

        // Reopen the sheet
        setTargetScreen.openSheet()
        let savedRow = setTargetScreen.savedTargetRow(for: "delete.example.com")
        XCTAssertTrue(savedRow.waitForExistence(timeout: 5), "Saved target row should exist before delete")

        // Swipe left to reveal the delete action
        savedRow.swipeLeft()

        // Tap the Delete button that appears
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 3) {
            deleteButton.tap()
        }

        // Row should no longer exist
        XCTAssertFalse(
            setTargetScreen.savedTargetRow(for: "delete.example.com").waitForExistence(timeout: 3),
            "Saved target should be removed after swipe-to-delete"
        )
    }

    // MARK: - Cancel Tests

    func testCancelToolbarButtonDismissesWithoutChanges() {
        // Note the current label of the quick action button
        let labelBefore = setTargetScreen.setTargetQuickActionButton.label

        setTargetScreen.openSheet()
        // Type something but do NOT tap Set
        setTargetScreen.enterAddress("unsaved.example.com")
        setTargetScreen.tapCancel()

        XCTAssertFalse(
            setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 5),
            "Sheet should be dismissed after tapping Cancel"
        )
        // Quick action button label should be unchanged
        XCTAssertEqual(
            setTargetScreen.setTargetQuickActionButton.label,
            labelBefore,
            "Quick action button label should not change after cancelling"
        )
    }

    // MARK: - Pre-fill Tests

    func testTargetPreFillsPingToolHostField() {
        // Set a target
        setTargetScreen.openSheet()
        setTargetScreen.enterAddress("ping.example.com")
        setTargetScreen.tapSet()
        _ = !setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 3)

        // Navigate to Ping tool
        let pingScreen = toolsScreen.openPingTool()
        XCTAssertTrue(pingScreen.isDisplayed(), "Ping tool should open")

        // Host field should be pre-filled with the active target
        XCTAssertTrue(
            pingScreen.hostInput.waitForExistence(timeout: 5),
            "Ping tool host input field should exist"
        )
        let fieldValue = pingScreen.hostInput.value as? String ?? ""
        XCTAssertEqual(
            fieldValue,
            "ping.example.com",
            "Ping tool host field should be pre-filled with the active target"
        )
    }

    func testTargetPreFillsDNSLookupDomainField() {
        // Set a target
        setTargetScreen.openSheet()
        setTargetScreen.enterAddress("dns.example.com")
        setTargetScreen.tapSet()
        _ = !setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 3)

        // Navigate to DNS Lookup tool
        let dnsScreen = toolsScreen.openDNSLookupTool()
        XCTAssertTrue(dnsScreen.isDisplayed(), "DNS Lookup tool should open")

        // Domain field should be pre-filled with the active target
        XCTAssertTrue(
            dnsScreen.domainInput.waitForExistence(timeout: 5),
            "DNS Lookup tool domain input field should exist"
        )
        let fieldValue = dnsScreen.domainInput.value as? String ?? ""
        XCTAssertEqual(
            fieldValue,
            "dns.example.com",
            "DNS Lookup tool domain field should be pre-filled with the active target"
        )
    }

    func testTargetPreFillsPortScannerHostField() {
        // Set a target
        setTargetScreen.openSheet()
        setTargetScreen.enterAddress("portscan.example.com")
        setTargetScreen.tapSet()
        _ = !setTargetScreen.sheetNavigationBar.waitForExistence(timeout: 3)

        // Navigate to Port Scanner tool
        let portScanScreen = toolsScreen.openPortScannerTool()
        XCTAssertTrue(portScanScreen.isDisplayed(), "Port Scanner tool should open")

        // Host field should be pre-filled with the active target
        XCTAssertTrue(
            portScanScreen.hostInput.waitForExistence(timeout: 5),
            "Port Scanner tool host input field should exist"
        )
        let fieldValue = portScanScreen.hostInput.value as? String ?? ""
        XCTAssertEqual(
            fieldValue,
            "portscan.example.com",
            "Port Scanner tool host field should be pre-filled with the active target"
        )
    }
}
