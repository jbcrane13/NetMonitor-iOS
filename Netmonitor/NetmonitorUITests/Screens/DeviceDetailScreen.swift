import XCTest

/// Device Detail screen page object
final class DeviceDetailScreen: BaseScreen {

    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_deviceDetail"]
    }

    // MARK: - Loading & Error States
    var loadingIndicator: XCUIElement {
        app.activityIndicators["deviceDetail_progress_loading"]
    }

    var notFoundLabel: XCUIElement {
        app.staticTexts["deviceDetail_label_notFound"]
    }

    // MARK: - Header Elements
    var deviceTypeIcon: XCUIElement {
        app.images["deviceDetail_icon_deviceType"]
    }

    var displayName: XCUIElement {
        app.staticTexts["deviceDetail_label_displayName"]
    }

    var statusBadge: XCUIElement {
        app.staticTexts["deviceDetail_label_status"]
    }

    var manufacturerLabel: XCUIElement {
        app.staticTexts["deviceDetail_label_manufacturer"]
    }

    // MARK: - Network Info Section
    var networkInfoTitle: XCUIElement {
        app.staticTexts["deviceDetail_label_networkInfoTitle"]
    }

    var ipAddressRow: XCUIElement {
        app.descendants(matching: .any)["deviceDetail_row_ipAddress"]
    }

    var macAddressRow: XCUIElement {
        app.descendants(matching: .any)["deviceDetail_row_macAddress"]
    }

    var hostnameRow: XCUIElement {
        app.descendants(matching: .any)["deviceDetail_row_hostname"]
    }

    var resolvedHostnameRow: XCUIElement {
        app.descendants(matching: .any)["deviceDetail_row_resolvedHostname"]
    }

    // MARK: - Status Section
    var statusTitle: XCUIElement {
        app.staticTexts["deviceDetail_label_statusTitle"]
    }

    var latencyRow: XCUIElement {
        app.descendants(matching: .any)["deviceDetail_row_latency"]
    }

    var firstSeenRow: XCUIElement {
        app.descendants(matching: .any)["deviceDetail_row_firstSeen"]
    }

    var lastSeenRow: XCUIElement {
        app.descendants(matching: .any)["deviceDetail_row_lastSeen"]
    }

    // MARK: - Quick Actions
    var pingButton: XCUIElement {
        app.buttons["deviceDetail_button_ping"]
    }

    var portScanButton: XCUIElement {
        app.buttons["deviceDetail_button_portScan"]
    }

    var dnsLookupButton: XCUIElement {
        app.buttons["deviceDetail_button_dnsLookup"]
    }

    var wakeOnLanButton: XCUIElement {
        app.buttons["deviceDetail_button_wakeOnLan"]
    }

    // MARK: - Services Section
    var servicesSection: XCUIElement {
        app.descendants(matching: .any)["deviceDetail_section_services"]
    }

    var scanPortsButton: XCUIElement {
        app.buttons["deviceDetail_button_scanPorts"]
    }

    var discoverServicesButton: XCUIElement {
        app.buttons["deviceDetail_button_discoverServices"]
    }

    // MARK: - Notes Section
    var notesEditor: XCUIElement {
        app.textViews["deviceDetail_textEditor_notes"]
    }

    // MARK: - Navigation

    /// Checks if there are any available devices to test with
    var hasAvailableDevices: Bool {
        // Navigate to Map tab
        navigateToTab("Map")

        // Wait for map screen to load
        let mapScreen = NetworkMapScreen(app: app)
        _ = mapScreen.isDisplayed()

        // Check for device nodes (excluding gateway)
        let deviceNodes = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'networkMap_node_' AND identifier != 'networkMap_node_gateway'")
        )

        return deviceNodes.count > 0
    }

    @discardableResult
    func navigateToDeviceDetail() -> Self {
        // Navigate to Map tab
        navigateToTab("Map")

        // Wait for map screen to load
        let mapScreen = NetworkMapScreen(app: app)
        _ = mapScreen.isDisplayed()

        // Tap the first available device node (excluding gateway)
        // Device nodes have identifiers like "networkMap_node_192_168_1_100"
        let deviceNodes = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'networkMap_node_' AND identifier != 'networkMap_node_gateway'")
        )

        if deviceNodes.count > 0 {
            deviceNodes.element(boundBy: 0).tap()
            // Wait for detail screen to appear
            _ = waitForElement(screen)
        }

        return self
    }

    // MARK: - Verification
    func isDisplayed() -> Bool {
        waitForElement(screen) || waitForElement(displayName)
    }

    func verifyNetworkInfoPresent() -> Bool {
        waitForElement(networkInfoTitle) ||
        waitForElement(ipAddressRow) ||
        waitForElement(macAddressRow)
    }

    func verifyQuickActionsPresent() -> Bool {
        waitForElement(pingButton) ||
        waitForElement(portScanButton) ||
        waitForElement(dnsLookupButton)
    }

    func verifyNotesPresent() -> Bool {
        waitForElement(notesEditor)
    }

    func verifyServicesPresent() -> Bool {
        waitForElement(servicesSection) ||
        waitForElement(scanPortsButton) ||
        waitForElement(discoverServicesButton)
    }
}
