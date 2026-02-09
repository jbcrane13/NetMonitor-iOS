import XCTest

/// UI tests for the Settings screen
final class SettingsUITests: XCTestCase {
    
    var app: XCUIApplication!
    var settingsScreen: SettingsScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Navigate to Settings via Dashboard
        let dashboardScreen = DashboardScreen(app: app)
        settingsScreen = dashboardScreen.openSettings()
    }
    
    override func tearDown() {
        app = nil
        settingsScreen = nil
        super.tearDown()
    }
    
    // MARK: - Screen Loading Tests
    
    func testSettingsScreenLoads() {
        XCTAssertTrue(settingsScreen.isDisplayed(), "Settings screen should load")
    }
    
    // MARK: - Network Tools Settings Tests
    
    func testPingCountStepperExists() {
        XCTAssertTrue(
            settingsScreen.pingCountStepper.waitForExistence(timeout: 5) ||
            settingsScreen.pingCountText.waitForExistence(timeout: 3),
            "Ping count stepper should exist"
        )
    }

    func testPingTimeoutStepperExists() {
        XCTAssertTrue(
            settingsScreen.pingTimeoutStepper.waitForExistence(timeout: 5) ||
            settingsScreen.pingTimeoutText.waitForExistence(timeout: 3),
            "Ping timeout stepper should exist"
        )
    }

    func testPortScanTimeoutStepperExists() {
        XCTAssertTrue(
            settingsScreen.portScanTimeoutStepper.waitForExistence(timeout: 5) ||
            settingsScreen.portScanTimeoutText.waitForExistence(timeout: 3),
            "Port scan timeout stepper should exist"
        )
    }
    
    func testDNSServerTextFieldExists() {
        XCTAssertTrue(
            settingsScreen.dnsServerTextField.waitForExistence(timeout: 5),
            "DNS server text field should exist"
        )
    }
    
    // MARK: - Monitoring Settings Tests
    
    func testAutoRefreshPickerExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.autoRefreshPicker.waitForExistence(timeout: 5) ||
            settingsScreen.autoRefreshText.waitForExistence(timeout: 3),
            "Auto refresh picker should exist"
        )
    }
    
    func testBackgroundRefreshToggleExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.backgroundRefreshToggle.waitForExistence(timeout: 5),
            "Background refresh toggle should exist"
        )
    }
    
    // MARK: - Notification Settings Tests
    
    func testTargetDownAlertToggleExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.targetDownAlertToggle.waitForExistence(timeout: 5),
            "Target down alert toggle should exist"
        )
    }
    
    func testHighLatencyThresholdStepperExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.highLatencyThresholdStepper.waitForExistence(timeout: 5) ||
            app.staticTexts["High Latency Threshold"].waitForExistence(timeout: 3),
            "High latency threshold stepper should exist"
        )
    }
    
    func testNewDeviceAlertToggleExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.newDeviceAlertToggle.waitForExistence(timeout: 5),
            "New device alert toggle should exist"
        )
    }
    
    // MARK: - Appearance Settings Tests
    
    func testThemePickerExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.themePicker.waitForExistence(timeout: 5) ||
            settingsScreen.themeText.waitForExistence(timeout: 3),
            "Theme picker should exist"
        )
    }

    func testAccentColorPickerExists() {
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.accentColorPicker.waitForExistence(timeout: 5) ||
            settingsScreen.accentColorText.waitForExistence(timeout: 3),
            "Accent color picker should exist"
        )
    }

    // MARK: - Data & Privacy Tests

    func testDataRetentionPickerExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.dataRetentionPicker.waitForExistence(timeout: 5) ||
            settingsScreen.dataRetentionText.waitForExistence(timeout: 3),
            "Data retention picker should exist"
        )
    }

    func testShowDetailedResultsToggleExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.showDetailedResultsToggle.waitForExistence(timeout: 5) ||
            app.staticTexts["Show Detailed Results"].waitForExistence(timeout: 3),
            "Show detailed results toggle should exist"
        )
    }
    
    func testClearHistoryButtonExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.clearHistoryButton.waitForExistence(timeout: 5),
            "Clear history button should exist"
        )
    }
    
    func testClearHistoryShowsAlert() {
        settingsScreen.tapClearHistory()
        
        XCTAssertTrue(
            settingsScreen.clearHistoryAlert.waitForExistence(timeout: 5),
            "Clear history alert should appear"
        )
    }
    
    func testClearHistoryAlertCanBeCancelled() {
        settingsScreen.tapClearHistory()
        _ = settingsScreen.clearHistoryAlert.waitForExistence(timeout: 5)
        
        settingsScreen.cancelClearHistory()
        
        // Alert should be dismissed
        XCTAssertFalse(
            settingsScreen.clearHistoryAlert.exists,
            "Clear history alert should be dismissed after cancel"
        )
    }
    
    func testClearCacheButtonExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.clearCacheButton.waitForExistence(timeout: 5),
            "Clear cache button should exist"
        )
    }
    
    func testClearCacheShowsAlert() {
        settingsScreen.tapClearCache()
        
        XCTAssertTrue(
            settingsScreen.clearCacheAlert.waitForExistence(timeout: 5),
            "Clear cache alert should appear"
        )
    }
    
    func testClearCacheAlertCanBeCancelled() {
        settingsScreen.tapClearCache()
        _ = settingsScreen.clearCacheAlert.waitForExistence(timeout: 5)
        
        settingsScreen.cancelClearCache()
        
        XCTAssertFalse(
            settingsScreen.clearCacheAlert.exists,
            "Clear cache alert should be dismissed after cancel"
        )
    }

    // MARK: - Export Tests

    func testExportToolResultsMenuExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.exportToolResultsMenu.waitForExistence(timeout: 5),
            "Export tool results menu should exist"
        )
    }

    func testExportSpeedTestsMenuExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.exportSpeedTestsMenu.waitForExistence(timeout: 5),
            "Export speed tests menu should exist"
        )
    }

    func testExportDevicesMenuExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.exportDevicesMenu.waitForExistence(timeout: 5),
            "Export devices menu should exist"
        )
    }

    // MARK: - About Section Tests
    
    func testAppVersionRowExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.appVersionRow.waitForExistence(timeout: 5) ||
            settingsScreen.appVersionText.waitForExistence(timeout: 3),
            "App version row should exist"
        )
    }

    func testBuildNumberRowExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.buildNumberRow.waitForExistence(timeout: 5) ||
            settingsScreen.buildNumberText.waitForExistence(timeout: 3),
            "Build number row should exist"
        )
    }

    func testIOSVersionRowExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.iosVersionRow.waitForExistence(timeout: 5) ||
            settingsScreen.iosVersionText.waitForExistence(timeout: 3),
            "iOS version row should exist"
        )
    }
    
    func testAcknowledgementsLinkExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.acknowledgementsLink.waitForExistence(timeout: 5),
            "Acknowledgements link should exist"
        )
    }

    func testSupportLinkExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        // SwiftUI Link may render as app.links or app.buttons depending on iOS version
        XCTAssertTrue(
            settingsScreen.supportLink.waitForExistence(timeout: 5) ||
            settingsScreen.supportLinkAsButton.waitForExistence(timeout: 3) ||
            settingsScreen.supportLinkText.waitForExistence(timeout: 3),
            "Support link should exist"
        )
    }

    func testRateAppButtonExists() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        XCTAssertTrue(
            settingsScreen.rateAppButton.waitForExistence(timeout: 5),
            "Rate app button should exist"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        settingsScreen.navigateBack()
        
        let dashboardScreen = DashboardScreen(app: app)
        XCTAssertTrue(dashboardScreen.isDisplayed(), "Should return to Dashboard")
    }
}
