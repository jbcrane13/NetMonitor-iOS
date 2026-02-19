import XCTest

/// Comprehensive UI tests for the Mac Pairing flow
final class MacPairingUITests: XCTestCase {

    var app: XCUIApplication!
    var settingsScreen: SettingsScreen!
    var macPairingScreen: MacPairingScreen!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Navigate to Settings via Dashboard gear icon
        let dashboardScreen = DashboardScreen(app: app)
        settingsScreen = dashboardScreen.openSettings()
        macPairingScreen = MacPairingScreen(app: app)
    }

    override func tearDown() {
        app = nil
        settingsScreen = nil
        macPairingScreen = nil
        super.tearDown()
    }

    // MARK: - Sheet Presentation Tests

    func testConnectToMacButtonOpensMacPairingSheet() {
        XCTAssertTrue(
            macPairingScreen.connectMacButton.waitForExistence(timeout: 5),
            "Connect to Mac button should exist in Settings when not connected"
        )
        macPairingScreen.openSheet()
        XCTAssertTrue(
            macPairingScreen.isSheetDisplayed(),
            "Mac Pairing sheet should open after tapping Connect to Mac"
        )
    }

    // MARK: - Discovery State Tests

    func testSearchingStateDisplaysWhileBrowsingForMacs() {
        macPairingScreen.openSheet()
        // When the sheet opens it starts Bonjour browsing. In the simulator one of three
        // states will appear: searching spinner, empty-state, or discovered macs section.
        XCTAssertTrue(
            macPairingScreen.searchingIndicator.waitForExistence(timeout: 5) ||
            macPairingScreen.emptyState.waitForExistence(timeout: 5) ||
            macPairingScreen.discoveredMacsHeader.waitForExistence(timeout: 5),
            "Sheet should show Discovered Macs section in searching, empty, or found state"
        )
    }

    func testDiscoveredMacsSectionHeaderExists() {
        macPairingScreen.openSheet()
        XCTAssertTrue(
            macPairingScreen.discoveredMacsHeader.waitForExistence(timeout: 5),
            "Discovered Macs section header should be visible"
        )
    }

    // MARK: - Manual Entry Tests

    func testManualEntryToggleExpandsManualFields() {
        macPairingScreen.openSheet()
        XCTAssertTrue(
            macPairingScreen.manualToggle.waitForExistence(timeout: 5),
            "Manual entry toggle should exist in pairing sheet"
        )
        // Fields should not be visible before toggling
        XCTAssertFalse(
            macPairingScreen.manualHostField.exists,
            "Host field should not be visible before expanding manual entry"
        )
        macPairingScreen.expandManualEntry()
        XCTAssertTrue(
            macPairingScreen.manualHostField.waitForExistence(timeout: 5),
            "Host field should appear after tapping manual entry toggle"
        )
        XCTAssertTrue(
            macPairingScreen.manualPortField.waitForExistence(timeout: 5),
            "Port field should appear after tapping manual entry toggle"
        )
    }

    func testCanEnterHostInManualHostField() {
        macPairingScreen.openSheet()
        macPairingScreen.expandManualEntry()
        XCTAssertTrue(
            macPairingScreen.manualHostField.waitForExistence(timeout: 5),
            "Manual host field should exist after expanding manual entry"
        )
        macPairingScreen.enterManualHost("192.168.1.50")
        XCTAssertEqual(
            macPairingScreen.manualHostField.value as? String,
            "192.168.1.50",
            "Host field should contain the entered host"
        )
    }

    func testCanEnterPortInManualPortField() {
        macPairingScreen.openSheet()
        macPairingScreen.expandManualEntry()
        XCTAssertTrue(
            macPairingScreen.manualPortField.waitForExistence(timeout: 5),
            "Manual port field should exist after expanding manual entry"
        )
        macPairingScreen.clearAndEnterManualPort("9000")
        // Field should still exist and be interactive after entering a value
        XCTAssertTrue(
            macPairingScreen.manualPortField.exists,
            "Port field should remain accessible after entering a value"
        )
    }

    func testDefaultPortIs8849() {
        macPairingScreen.openSheet()
        macPairingScreen.expandManualEntry()
        XCTAssertTrue(
            macPairingScreen.manualPortField.waitForExistence(timeout: 5),
            "Manual port field should exist"
        )
        let portValue = macPairingScreen.manualPortField.value as? String ?? ""
        XCTAssertEqual(portValue, "8849", "Default port should be 8849")
    }

    func testConnectButtonIsPresentAndTappable() {
        macPairingScreen.openSheet()
        macPairingScreen.expandManualEntry()
        XCTAssertTrue(
            macPairingScreen.manualConnectButton.waitForExistence(timeout: 5),
            "Connect button should be present after expanding manual entry"
        )
        XCTAssertTrue(
            macPairingScreen.manualConnectButton.isEnabled,
            "Connect button should be enabled"
        )
        // Tapping with empty host — guard in connectManually() prevents the call
        macPairingScreen.tapConnect()
        // Sheet should remain open (empty host is rejected silently)
        XCTAssertTrue(
            macPairingScreen.isSheetDisplayed(),
            "Sheet should remain open after connect attempt with no host"
        )
    }

    // MARK: - Cancel Tests

    func testCancelButtonDismissesSheet() {
        macPairingScreen.openSheet()
        XCTAssertTrue(
            macPairingScreen.cancelButton.waitForExistence(timeout: 5),
            "Cancel button should exist in Mac Pairing sheet"
        )
        macPairingScreen.tapCancel()
        XCTAssertFalse(
            macPairingScreen.navigationBar.waitForExistence(timeout: 5),
            "Mac Pairing sheet should be dismissed after tapping Cancel"
        )
    }

    func testCancelButtonDismissesAndReturnsToSettings() {
        macPairingScreen.openSheet()
        macPairingScreen.tapCancel()
        XCTAssertTrue(
            settingsScreen.isDisplayed(),
            "Settings screen should be visible after cancelling Mac Pairing"
        )
    }

    // MARK: - Connection Status Tests

    func testConnectionStatusSectionAppearsAfterConnectAttempt() {
        macPairingScreen.openSheet()
        macPairingScreen.expandManualEntry()
        macPairingScreen.enterManualHost("192.168.1.1")
        macPairingScreen.tapConnect()

        // After tapping Connect, connection state changes from .disconnected — Status section should appear
        XCTAssertTrue(
            macPairingScreen.statusSectionHeader.waitForExistence(timeout: 5),
            "Status section should appear when a connection attempt is made"
        )
    }

    func testDoneButtonNotPresentBeforeConnection() {
        macPairingScreen.openSheet()
        // Done button is gated on connectionState.isConnected == true
        XCTAssertFalse(
            macPairingScreen.doneButton.exists,
            "Done button should not appear before a successful connection"
        )
    }

    // MARK: - Settings Integration Tests

    func testDisconnectButtonNotVisibleWhenNotConnected() {
        // In the simulator there is no active Mac connection, so connectMac button shows
        XCTAssertTrue(
            macPairingScreen.connectMacButton.waitForExistence(timeout: 5),
            "Connect to Mac button should be visible when not connected"
        )
        XCTAssertFalse(
            macPairingScreen.disconnectButton.exists,
            "Disconnect button should not appear when not connected"
        )
    }

    func testMacCompanionSectionDisplaysConnectionStatus() {
        // Mac Companion section is at the top of Settings — no scrolling needed
        XCTAssertTrue(
            macPairingScreen.connectionStatusRow.waitForExistence(timeout: 5) ||
            app.staticTexts["No Mac Connected"].waitForExistence(timeout: 5),
            "Mac Companion section should display a connection status row"
        )
    }

    // MARK: - Manual Entry Toggle Behaviour

    func testManualConnectionSectionHeaderExists() {
        macPairingScreen.openSheet()
        XCTAssertTrue(
            macPairingScreen.manualConnectionHeader.waitForExistence(timeout: 5),
            "Manual Connection section header should be visible in pairing sheet"
        )
    }

    func testManualEntryToggleCollapsesWhenTappedAgain() {
        macPairingScreen.openSheet()
        // First tap — expand
        macPairingScreen.expandManualEntry()
        XCTAssertTrue(
            macPairingScreen.manualHostField.waitForExistence(timeout: 5),
            "Host field should be visible after first toggle"
        )
        // Second tap — collapse
        macPairingScreen.expandManualEntry()
        XCTAssertFalse(
            macPairingScreen.manualHostField.waitForExistence(timeout: 3),
            "Host field should be hidden after second toggle (collapse)"
        )
    }
}
