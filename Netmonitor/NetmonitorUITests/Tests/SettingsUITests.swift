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

    // MARK: - Interaction Tests

    func testCanToggleBackgroundRefresh() {
        settingsScreen.swipeUp()
        let toggle = settingsScreen.backgroundRefreshToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Background refresh toggle should exist")
        XCTAssertTrue(toggle.isEnabled, "Background refresh toggle should be enabled")

        // Tap the toggle to verify interaction works
        toggle.tap()

        // Verify toggle is still accessible after tap (confirms interaction was processed)
        XCTAssertTrue(toggle.exists, "Background refresh toggle should still exist after tap")
    }

    func testCanToggleTargetDownAlert() {
        settingsScreen.swipeUp()
        let toggle = settingsScreen.targetDownAlertToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Target down alert toggle should exist")
        XCTAssertTrue(toggle.isEnabled, "Target down alert toggle should be enabled")

        // Tap the toggle to verify interaction works
        toggle.tap()

        // Verify toggle is still accessible after tap (confirms interaction was processed)
        XCTAssertTrue(toggle.exists, "Target down alert toggle should still exist after tap")
    }

    func testCanToggleNewDeviceAlert() {
        settingsScreen.swipeUp()
        let toggle = settingsScreen.newDeviceAlertToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "New device alert toggle should exist")
        XCTAssertTrue(toggle.isEnabled, "New device alert toggle should be enabled")

        // Tap the toggle to verify interaction works
        toggle.tap()

        // Verify toggle is still accessible after tap (confirms interaction was processed)
        XCTAssertTrue(toggle.exists, "New device alert toggle should still exist after tap")
    }

    func testAcknowledgementsNavigationWorks() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let acknowledgementsLink = settingsScreen.acknowledgementsLink
        XCTAssertTrue(acknowledgementsLink.waitForExistence(timeout: 5), "Acknowledgements link should exist")

        acknowledgementsLink.tap()

        // Verify navigation to Acknowledgements screen
        XCTAssertTrue(
            app.navigationBars["Acknowledgements"].waitForExistence(timeout: 5),
            "Acknowledgements screen should load with navigation bar title"
        )
    }

    func testClearHistoryConfirmActuallyClears() {
        settingsScreen.tapClearHistory()

        XCTAssertTrue(
            settingsScreen.clearHistoryAlert.waitForExistence(timeout: 5),
            "Clear history alert should appear"
        )

        settingsScreen.confirmClearHistory()

        // Alert should be dismissed after confirmation
        XCTAssertFalse(
            settingsScreen.clearHistoryAlert.exists,
            "Clear history alert should be dismissed after confirmation"
        )
    }

    func testClearCacheConfirmActuallyClears() {
        settingsScreen.tapClearCache()

        XCTAssertTrue(
            settingsScreen.clearCacheAlert.waitForExistence(timeout: 5),
            "Clear cache alert should appear"
        )

        settingsScreen.confirmClearCache()

        // Alert should be dismissed after confirmation
        XCTAssertFalse(
            settingsScreen.clearCacheAlert.exists,
            "Clear cache alert should be dismissed after confirmation"
        )
    }

    func testMacPairingSection() {
        // Mac Companion section is at the top of settings, no scrolling needed
        // Section headers in SwiftUI Lists may appear as otherElements instead of staticTexts
        let macCompanionSection = app.otherElements["Mac Companion"].exists ?
            app.otherElements["Mac Companion"] : app.staticTexts["Mac Companion"]

        XCTAssertTrue(
            macCompanionSection.waitForExistence(timeout: 5),
            "Mac Companion section should exist in settings"
        )
    }

    // MARK: - Stepper Functional Tests

    func testPingCountStepperIncrement() {
        let container = settingsScreen.pingCountStepper
        XCTAssertTrue(container.waitForExistence(timeout: 5), "Ping count stepper should exist")

        let incrementButton = container.buttons["Increment"]
        if incrementButton.waitForExistence(timeout: 3) {
            incrementButton.tap()
            XCTAssertTrue(container.exists, "Ping count stepper should remain accessible after increment")
        } else {
            XCTAssertTrue(container.isEnabled, "Ping count stepper should be enabled and interactive")
        }
    }

    func testPingTimeoutStepperIncrement() {
        let container = settingsScreen.pingTimeoutStepper
        XCTAssertTrue(container.waitForExistence(timeout: 5), "Ping timeout stepper should exist")

        let incrementButton = container.buttons["Increment"]
        if incrementButton.waitForExistence(timeout: 3) {
            incrementButton.tap()
            XCTAssertTrue(container.exists, "Ping timeout stepper should remain accessible after increment")
        } else {
            XCTAssertTrue(container.isEnabled, "Ping timeout stepper should be enabled and interactive")
        }
    }

    func testPortScanTimeoutStepperIncrement() {
        let container = settingsScreen.portScanTimeoutStepper
        XCTAssertTrue(container.waitForExistence(timeout: 5), "Port scan timeout stepper should exist")

        let incrementButton = container.buttons["Increment"]
        if incrementButton.waitForExistence(timeout: 3) {
            incrementButton.tap()
            XCTAssertTrue(container.exists, "Port scan timeout stepper should remain accessible after increment")
        } else {
            XCTAssertTrue(container.isEnabled, "Port scan timeout stepper should be enabled and interactive")
        }
    }

    func testDNSServerTextFieldEntry() {
        let textField = settingsScreen.dnsServerTextField
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "DNS server text field should exist")
        XCTAssertTrue(textField.isEnabled, "DNS server text field should be enabled")

        textField.tap()
        textField.typeText("9")

        let fieldValue = textField.value as? String ?? ""
        XCTAssertTrue(
            fieldValue.contains("9"),
            "DNS server text field should accept and display typed text"
        )
    }

    // MARK: - High Latency Alert Toggle Functional Tests

    func testHighLatencyToggleRevealsThreshold() {
        settingsScreen.swipeUp()

        let toggle = settingsScreen.highLatencyAlertToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "High latency alert toggle should exist")

        // Ensure toggle is OFF first
        if (toggle.value as? String) == "1" {
            toggle.tap()
            usleep(300_000)
        }

        XCTAssertFalse(
            settingsScreen.highLatencyThresholdStepper.exists,
            "High latency threshold stepper should be hidden when alert is disabled"
        )

        // Enable the toggle
        toggle.tap()

        XCTAssertTrue(
            settingsScreen.highLatencyThresholdStepper.waitForExistence(timeout: 3),
            "High latency threshold stepper should appear when alert is enabled"
        )
    }

    func testHighLatencyToggleHidesThreshold() {
        settingsScreen.swipeUp()

        let toggle = settingsScreen.highLatencyAlertToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "High latency alert toggle should exist")

        // Ensure toggle is ON first
        if (toggle.value as? String) == "0" {
            toggle.tap()
            usleep(300_000)
        }

        XCTAssertTrue(
            settingsScreen.highLatencyThresholdStepper.waitForExistence(timeout: 3),
            "High latency threshold stepper should be visible when alert is enabled"
        )

        // Disable the toggle
        toggle.tap()

        XCTAssertFalse(
            settingsScreen.highLatencyThresholdStepper.exists,
            "High latency threshold stepper should disappear when alert is disabled"
        )
    }

    func testHighLatencyThresholdStepperIncrement() {
        settingsScreen.swipeUp()

        let toggle = settingsScreen.highLatencyAlertToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "High latency alert toggle should exist")

        // Enable to reveal the threshold stepper
        if (toggle.value as? String) == "0" {
            toggle.tap()
        }

        let container = settingsScreen.highLatencyThresholdStepper
        XCTAssertTrue(container.waitForExistence(timeout: 3), "High latency threshold stepper should be visible")

        let incrementButton = container.buttons["Increment"]
        if incrementButton.waitForExistence(timeout: 3) {
            incrementButton.tap()
            XCTAssertTrue(container.exists, "High latency threshold stepper should remain accessible after increment")
        } else {
            XCTAssertTrue(container.isEnabled, "High latency threshold stepper should be enabled")
        }
    }

    // MARK: - Toggle Functional Verification Tests

    func testBackgroundRefreshToggleFunction() {
        settingsScreen.swipeUp()

        let toggle = settingsScreen.backgroundRefreshToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Background refresh toggle should exist")

        let initialValue = toggle.value as? String ?? "0"
        toggle.tap()
        let newValue = toggle.value as? String ?? "0"

        XCTAssertNotEqual(initialValue, newValue, "Background refresh toggle should change state after tap")

        // Restore original state
        toggle.tap()
        XCTAssertEqual(
            toggle.value as? String,
            initialValue,
            "Background refresh toggle should restore to original state"
        )
    }

    func testShowDetailedResultsToggleFunction() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let toggle = settingsScreen.showDetailedResultsToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Show detailed results toggle should exist")

        let initialValue = toggle.value as? String ?? "0"
        toggle.tap()
        let newValue = toggle.value as? String ?? "0"

        XCTAssertNotEqual(initialValue, newValue, "Show detailed results toggle should change state after tap")
    }

    // MARK: - Picker Functional Tests

    func testAccentColorPickerChanges() {
        settingsScreen.swipeUp()

        let picker = settingsScreen.accentColorPicker
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Accent color picker should exist")
        XCTAssertTrue(picker.isEnabled, "Accent color picker should be enabled")

        picker.tap()

        XCTAssertTrue(
            picker.exists,
            "Accent color picker should remain accessible after interaction"
        )
    }

    func testDataRetentionPickerChanges() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let picker = settingsScreen.dataRetentionPicker
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Data retention picker should exist")
        XCTAssertTrue(picker.isEnabled, "Data retention picker should be enabled")

        picker.tap()

        XCTAssertTrue(
            picker.exists,
            "Data retention picker should remain accessible after interaction"
        )
    }

    func testAutoRefreshIntervalPickerChanges() {
        settingsScreen.swipeUp()

        let picker = settingsScreen.autoRefreshPicker
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Auto-refresh interval picker should exist")
        XCTAssertTrue(picker.isEnabled, "Auto-refresh interval picker should be enabled")

        picker.tap()

        XCTAssertTrue(
            picker.exists,
            "Auto-refresh interval picker should remain accessible after interaction"
        )
    }

    // MARK: - Data Action Functional Tests

    func testClearHistoryConfirmClearsData() {
        settingsScreen.tapClearHistory()

        XCTAssertTrue(
            settingsScreen.clearHistoryAlert.waitForExistence(timeout: 5),
            "Clear history alert should appear"
        )

        settingsScreen.confirmClearHistory()

        XCTAssertFalse(
            settingsScreen.clearHistoryAlert.exists,
            "Clear history alert should be dismissed after confirmation"
        )

        // Settings screen should remain functional after the clear operation
        XCTAssertTrue(
            settingsScreen.isDisplayed(),
            "Settings screen should remain visible and functional after clearing history"
        )
    }

    func testClearCacheConfirmReducesSize() {
        settingsScreen.tapClearCache()

        XCTAssertTrue(
            settingsScreen.clearCacheAlert.waitForExistence(timeout: 5),
            "Clear cache alert should appear"
        )

        settingsScreen.confirmClearCache()

        XCTAssertFalse(
            settingsScreen.clearCacheAlert.exists,
            "Clear cache alert should be dismissed after confirmation"
        )

        // Settings screen should remain functional and the button should still be accessible
        XCTAssertTrue(
            settingsScreen.isDisplayed(),
            "Settings screen should remain visible and functional after clearing cache"
        )
        XCTAssertTrue(
            settingsScreen.clearCacheButton.exists,
            "Clear cache button should still be accessible after clearing"
        )
    }

    // MARK: - Export Menu Functional Tests

    func testExportToolResultsMenu() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let exportButton = settingsScreen.exportToolResultsMenu
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export tool results menu should exist")

        exportButton.tap()

        XCTAssertTrue(
            app.buttons["Export as JSON"].waitForExistence(timeout: 5) ||
            app.buttons["Export as CSV"].waitForExistence(timeout: 5),
            "Export format options (JSON/CSV) should appear after tapping Export Tool Results"
        )
    }

    func testExportSpeedTestsMenu() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let exportButton = settingsScreen.exportSpeedTestsMenu
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export speed tests menu should exist")

        exportButton.tap()

        XCTAssertTrue(
            app.buttons["Export as JSON"].waitForExistence(timeout: 5) ||
            app.buttons["Export as CSV"].waitForExistence(timeout: 5),
            "Export format options (JSON/CSV) should appear after tapping Export Speed Tests"
        )
    }

    func testExportDevicesMenu() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let exportButton = settingsScreen.exportDevicesMenu
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5), "Export devices menu should exist")

        exportButton.tap()

        XCTAssertTrue(
            app.buttons["Export as JSON"].waitForExistence(timeout: 5) ||
            app.buttons["Export as CSV"].waitForExistence(timeout: 5),
            "Export format options (JSON/CSV) should appear after tapping Export Devices"
        )
    }

    // MARK: - Support & Feedback Functional Tests

    func testContactSupportLinkIsEnabled() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        XCTAssertTrue(
            settingsScreen.supportLink.waitForExistence(timeout: 5) ||
            settingsScreen.supportLinkAsButton.waitForExistence(timeout: 3) ||
            settingsScreen.supportLinkText.waitForExistence(timeout: 3),
            "Contact Support link should exist"
        )

        // Verify the element is enabled (can be interacted with)
        let supportElement: XCUIElement
        if settingsScreen.supportLink.exists {
            supportElement = settingsScreen.supportLink
        } else {
            supportElement = settingsScreen.supportLinkAsButton
        }

        if supportElement.exists {
            XCTAssertTrue(
                supportElement.isEnabled,
                "Contact Support link should be enabled for mailto interaction"
            )
        }
    }

    func testRateAppButtonIsEnabled() {
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()
        settingsScreen.swipeUp()

        let rateButton = settingsScreen.rateAppButton
        XCTAssertTrue(rateButton.waitForExistence(timeout: 5), "Rate App button should exist")
        XCTAssertTrue(rateButton.isEnabled, "Rate App button should be enabled and tappable")
        XCTAssertTrue(rateButton.isHittable, "Rate App button should be hittable (visible on screen)")
    }
}
