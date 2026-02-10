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

    func testDeviceDetailScreenLoads() {
        detailScreen.navigateToDeviceDetail()
        XCTAssertTrue(detailScreen.isDisplayed(), "Device Detail screen should load")
    }

    func testNavigationFromNetworkMap() {
        // Start from Map tab
        detailScreen.navigateToTab("Map")
        let mapScreen = NetworkMapScreen(app: app)
        XCTAssertTrue(mapScreen.isDisplayed(), "Should start on Network Map")

        // Navigate to device detail
        detailScreen.navigateToDeviceDetail()
        XCTAssertTrue(detailScreen.isDisplayed(), "Should navigate to Device Detail")
    }

    // MARK: - Network Info Tests

    func testNetworkInfoSectionDisplays() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.verifyNetworkInfoPresent(),
            "Network info section should be displayed"
        )
    }

    func testIPAddressRowExists() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.ipAddressRow.waitForExistence(timeout: 5),
            "IP address row should exist"
        )
    }

    func testMACAddressRowExists() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.macAddressRow.waitForExistence(timeout: 5),
            "MAC address row should exist"
        )
    }

    // MARK: - Quick Actions Tests

    func testQuickActionsSectionDisplays() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.verifyQuickActionsPresent(),
            "Quick actions section should be displayed"
        )
    }

    func testPingButtonExists() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.pingButton.waitForExistence(timeout: 5),
            "Ping button should exist"
        )
    }

    func testPortScanButtonExists() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.portScanButton.waitForExistence(timeout: 5),
            "Port Scan button should exist"
        )
    }

    func testDNSLookupButtonExists() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.dnsLookupButton.waitForExistence(timeout: 5),
            "DNS Lookup button should exist"
        )
    }

    // MARK: - Notes Tests

    func testNotesSectionDisplays() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.verifyNotesPresent(),
            "Notes section should be displayed"
        )
    }

    func testNotesEditorExists() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.notesEditor.waitForExistence(timeout: 5),
            "Notes editor should exist"
        )
    }

    // MARK: - Header Tests

    func testDeviceNameDisplays() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.displayName.waitForExistence(timeout: 5),
            "Device name should be displayed"
        )
    }

    func testDeviceTypeIconDisplays() {
        detailScreen.navigateToDeviceDetail()

        XCTAssertTrue(
            detailScreen.deviceTypeIcon.waitForExistence(timeout: 5),
            "Device type icon should be displayed"
        )
    }

    // MARK: - Services Tests

    func testServicesSectionCanBeDisplayed() {
        detailScreen.navigateToDeviceDetail()

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
