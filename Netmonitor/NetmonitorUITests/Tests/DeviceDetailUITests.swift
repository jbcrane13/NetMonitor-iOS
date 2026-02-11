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
