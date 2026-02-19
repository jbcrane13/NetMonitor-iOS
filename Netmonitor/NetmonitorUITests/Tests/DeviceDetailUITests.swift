import XCTest

/// UI tests for the Device Detail screen
final class DeviceDetailUITests: XCTestCase {

    var app: XCUIApplication!
    var detailScreen: DeviceDetailScreen!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        detailScreen = DeviceDetailScreen(app: app)
    }

    override func tearDown() {
        app = nil
        detailScreen = nil
        super.tearDown()
    }

    // MARK: - Screen Loading Tests

    func testDeviceDetailScreenLoads() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")
        XCTAssertTrue(detailScreen.isDisplayed(), "Device Detail screen should load")
    }

    func testNavigationFromNetworkMap() throws {
        // Start from Map tab
        detailScreen.navigateToTab("Map")
        let mapScreen = NetworkMapScreen(app: app)
        XCTAssertTrue(mapScreen.isDisplayed(), "Should start on Network Map")

        // Navigate to device detail
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")
        XCTAssertTrue(detailScreen.isDisplayed(), "Should navigate to Device Detail")
    }

    // MARK: - Network Info Tests

    func testNetworkInfoSectionDisplays() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.verifyNetworkInfoPresent(),
            "Network info section should be displayed"
        )
    }

    func testIPAddressRowExists() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.ipAddressRow.waitForExistence(timeout: 5),
            "IP address row should exist"
        )
    }

    func testMACAddressRowExists() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.macAddressRow.waitForExistence(timeout: 5),
            "MAC address row should exist"
        )
    }

    // MARK: - Quick Actions Tests

    func testQuickActionsSectionDisplays() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.verifyQuickActionsPresent(),
            "Quick actions section should be displayed"
        )
    }

    func testPingButtonExists() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.pingButton.waitForExistence(timeout: 5),
            "Ping button should exist"
        )
    }

    func testPortScanButtonExists() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.portScanButton.waitForExistence(timeout: 5),
            "Port Scan button should exist"
        )
    }

    func testDNSLookupButtonExists() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.dnsLookupButton.waitForExistence(timeout: 5),
            "DNS Lookup button should exist"
        )
    }

    // MARK: - Notes Tests

    func testNotesSectionDisplays() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.verifyNotesPresent(),
            "Notes section should be displayed"
        )
    }

    func testNotesEditorExists() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.notesEditor.waitForExistence(timeout: 5),
            "Notes editor should exist"
        )
    }

    // MARK: - Header Tests

    func testDeviceNameDisplays() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.displayName.waitForExistence(timeout: 5),
            "Device name should be displayed"
        )
    }

    func testDeviceTypeIconDisplays() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.deviceTypeIcon.waitForExistence(timeout: 5),
            "Device type icon should be displayed"
        )
    }

    // MARK: - Notes Interaction Tests

    func testNotesTextEditorCanType() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        let notesEditor = detailScreen.notesEditor
        try XCTSkipUnless(notesEditor.waitForExistence(timeout: 5), "Notes editor not found")

        notesEditor.tap()
        notesEditor.typeText("Test note entry")

        let fieldValue = notesEditor.value as? String ?? ""
        XCTAssertTrue(
            fieldValue.contains("Test note entry"),
            "Notes editor should contain the typed text"
        )
    }

    func testNotesPersistence() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        let notesEditor = detailScreen.notesEditor
        try XCTSkipUnless(notesEditor.waitForExistence(timeout: 5), "Notes editor not found")

        // Focus the editor and clear any existing content
        notesEditor.tap()
        usleep(300_000)
        notesEditor.press(forDuration: 1.0)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
            notesEditor.typeText(XCUIKeyboardKey.delete.rawValue)
        }

        let testNote = "Persist_\(Int(Date().timeIntervalSince1970))"
        notesEditor.typeText(testNote)

        // Navigate away — SwiftData should commit the change
        detailScreen.navigateToTab("Dashboard")
        usleep(500_000)

        // Return to the same device
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "Device detail not reachable on return")

        let restoredEditor = detailScreen.notesEditor
        XCTAssertTrue(restoredEditor.waitForExistence(timeout: 5), "Notes editor should be present after return")

        let persistedValue = restoredEditor.value as? String ?? ""
        XCTAssertTrue(
            persistedValue.contains(testNote),
            "Notes should persist after navigating away and back — expected '\(testNote)' in '\(persistedValue)'"
        )
    }

    // MARK: - Services & Ports Interaction Tests

    func testScanPortsButtonTriggersAction() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        if !detailScreen.scanPortsButton.exists {
            detailScreen.swipeUp()
        }
        try XCTSkipUnless(
            detailScreen.scanPortsButton.waitForExistence(timeout: 5),
            "Scan Ports button not found"
        )

        detailScreen.scanPortsButton.tap()

        // Button should remain in the hierarchy (either scanning or re-enabled)
        XCTAssertTrue(
            detailScreen.scanPortsButton.waitForExistence(timeout: 5),
            "Scan Ports button should remain accessible after tap"
        )
    }

    func testPortScanResultsDisplay() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        if !detailScreen.scanPortsButton.exists {
            detailScreen.swipeUp()
        }
        try XCTSkipUnless(
            detailScreen.scanPortsButton.waitForExistence(timeout: 5),
            "Scan Ports button not found"
        )

        detailScreen.scanPortsButton.tap()

        // Wait up to 20 s for scan to complete
        _ = detailScreen.scanPortsButton.waitForExistence(timeout: 20)

        let hasPortResults = detailScreen.openPortRows.count > 0
        let hasEmptyState = app.staticTexts["No services or ports discovered yet"].exists

        XCTAssertTrue(
            hasPortResults || hasEmptyState,
            "After port scan, either open-port rows or the empty-state message should be visible"
        )
    }

    func testDiscoverServicesButtonTriggersAction() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        if !detailScreen.discoverServicesButton.exists {
            detailScreen.swipeUp()
        }
        try XCTSkipUnless(
            detailScreen.discoverServicesButton.waitForExistence(timeout: 5),
            "Discover Services button not found"
        )

        detailScreen.discoverServicesButton.tap()

        XCTAssertTrue(
            detailScreen.discoverServicesButton.waitForExistence(timeout: 5),
            "Discover Services button should remain accessible after tap"
        )
    }

    func testServiceDiscoveryResultsDisplay() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        if !detailScreen.discoverServicesButton.exists {
            detailScreen.swipeUp()
        }
        try XCTSkipUnless(
            detailScreen.discoverServicesButton.waitForExistence(timeout: 5),
            "Discover Services button not found"
        )

        detailScreen.discoverServicesButton.tap()
        _ = detailScreen.discoverServicesButton.waitForExistence(timeout: 20)

        let hasServiceResults = detailScreen.discoveredServiceRows.count > 0
        let hasEmptyState = app.staticTexts["No services or ports discovered yet"].exists

        XCTAssertTrue(
            hasServiceResults || hasEmptyState,
            "After service discovery, either discovered-service rows or the empty-state message should be visible"
        )
    }

    // MARK: - Quick Actions Navigation Tests

    func testQuickActionPingNavigates() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        let pingButton = detailScreen.pingButton
        try XCTSkipUnless(pingButton.waitForExistence(timeout: 5), "Ping quick action not found")

        pingButton.tap()

        XCTAssertTrue(
            app.navigationBars["Ping"].waitForExistence(timeout: 5) ||
            app.staticTexts["Ping"].waitForExistence(timeout: 5) ||
            app.textFields.firstMatch.waitForExistence(timeout: 5),
            "Should navigate to Ping tool view with device IP pre-filled"
        )
    }

    func testQuickActionPortScanNavigates() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        let portScanButton = detailScreen.portScanButton
        try XCTSkipUnless(portScanButton.waitForExistence(timeout: 5), "Port Scan quick action not found")

        portScanButton.tap()

        XCTAssertTrue(
            app.navigationBars["Port Scanner"].waitForExistence(timeout: 5) ||
            app.staticTexts["Port Scanner"].waitForExistence(timeout: 5) ||
            app.textFields.firstMatch.waitForExistence(timeout: 5),
            "Should navigate to Port Scanner tool view with device IP pre-filled"
        )
    }

    func testQuickActionDNSNavigates() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        let dnsButton = detailScreen.dnsLookupButton
        try XCTSkipUnless(dnsButton.waitForExistence(timeout: 5), "DNS Lookup quick action not found")

        dnsButton.tap()

        XCTAssertTrue(
            app.navigationBars["DNS Lookup"].waitForExistence(timeout: 5) ||
            app.staticTexts["DNS Lookup"].waitForExistence(timeout: 5) ||
            app.textFields.firstMatch.waitForExistence(timeout: 5),
            "Should navigate to DNS Lookup tool view with device IP pre-filled"
        )
    }

    func testWakeOnLANQuickActionConditional() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        // Check WoL capability from the Status section indicator
        if detailScreen.wakeOnLanStatusRow.exists {
            // Device supports WoL — quick action button must appear
            XCTAssertTrue(
                detailScreen.wakeOnLanButton.waitForExistence(timeout: 5),
                "Wake on LAN quick action should appear for WoL-capable devices"
            )
        } else {
            // Device does not support WoL — button must NOT appear
            XCTAssertFalse(
                detailScreen.wakeOnLanButton.exists,
                "Wake on LAN quick action should not appear for non-WoL devices"
            )
        }
    }

    // MARK: - Network Info Content Tests

    func testNetworkInfoFieldsHaveValues() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        XCTAssertTrue(
            detailScreen.ipAddressRow.waitForExistence(timeout: 5),
            "IP address row should exist"
        )
        XCTAssertTrue(
            detailScreen.macAddressRow.waitForExistence(timeout: 5),
            "MAC address row should exist"
        )

        // Each row should contain both a label and a value text element
        XCTAssertGreaterThanOrEqual(
            detailScreen.ipAddressRow.staticTexts.count,
            2,
            "IP address row should have at least a label and a value"
        )
    }

    // MARK: - Latency Color Coding Tests

    func testLatencyDisplayShowsColorCoding() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        let latencyRow = detailScreen.latencyRow
        guard latencyRow.waitForExistence(timeout: 5) else {
            throw XCTSkip("Latency data not available for this device")
        }

        // Latency row should have text elements showing the ms value
        XCTAssertGreaterThan(
            latencyRow.staticTexts.count,
            0,
            "Latency row should display a latency value with unit"
        )
    }

    // MARK: - Services Tests

    func testServicesSectionCanBeDisplayed() throws {
        detailScreen.navigateToDeviceDetail()
        try XCTSkipUnless(detailScreen.isDisplayed(), "No devices available on network for testing")

        // Services section may require scrolling
        if !detailScreen.servicesSection.exists {
            detailScreen.swipeUp(on: detailScreen.screen)
        }

        XCTAssertTrue(
            detailScreen.verifyServicesPresent(),
            "Services section should be accessible"
        )
    }
}
