import XCTest

final class NetmonitorUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: - Dashboard Flow

    func testDashboardLoads() {
        let mainScreen = app.otherElements["screen_main"]
        XCTAssertTrue(mainScreen.waitForExistence(timeout: 5), "Main screen should load")
    }

    func testDashboardTabExists() {
        // The tab bar should have a Dashboard tab
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should exist")
    }

    // MARK: - Settings Navigation

    func testSettingsScreenLoads() {
        // Navigate to Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            let settingsScreen = app.otherElements["screen_settings"]
            XCTAssertTrue(settingsScreen.waitForExistence(timeout: 5), "Settings screen should load")
        }
    }

    func testSettingsPingCountExists() {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            let stepper = app.otherElements["settings_stepper_pingCount"]
            XCTAssertTrue(stepper.waitForExistence(timeout: 5), "Ping count stepper should exist")
        }
    }

    func testSettingsClearHistoryButton() {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            let clearButton = app.buttons["settings_button_clearHistory"]
            // Scroll down to find it
            let settingsScreen = app.otherElements["screen_settings"]
            if settingsScreen.exists {
                settingsScreen.swipeUp()
            }
            if clearButton.waitForExistence(timeout: 5) {
                clearButton.tap()
                // Alert should appear
                let alert = app.alerts["Clear History"]
                XCTAssertTrue(alert.waitForExistence(timeout: 3), "Clear history alert should appear")
                alert.buttons["Cancel"].tap()
            }
        }
    }

    func testSettingsClearCacheButton() {
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.exists {
            settingsTab.tap()
            let settingsScreen = app.otherElements["screen_settings"]
            if settingsScreen.exists {
                settingsScreen.swipeUp()
            }
            let clearCacheButton = app.buttons["settings_button_clearCache"]
            if clearCacheButton.waitForExistence(timeout: 5) {
                clearCacheButton.tap()
                let alert = app.alerts["Clear All Cached Data"]
                XCTAssertTrue(alert.waitForExistence(timeout: 3), "Clear cache alert should appear")
                alert.buttons["Cancel"].tap()
            }
        }
    }

    // MARK: - Tools Navigation

    func testToolsTabExists() {
        let toolsTab = app.tabBars.buttons["Tools"]
        if toolsTab.exists {
            toolsTab.tap()
            let toolsScreen = app.otherElements["screen_tools"]
            XCTAssertTrue(toolsScreen.waitForExistence(timeout: 5), "Tools screen should load")
        }
    }

    // MARK: - Network Map Navigation

    func testNetworkMapTabExists() {
        let mapTab = app.tabBars.buttons["Network Map"]
        if mapTab.exists {
            mapTab.tap()
            let mapScreen = app.otherElements["screen_networkMap"]
            XCTAssertTrue(mapScreen.waitForExistence(timeout: 5), "Network Map screen should load")
        }
    }

    // MARK: - Tool Execution - Ping

    func testPingToolNavigation() {
        let toolsTab = app.tabBars.buttons["Tools"]
        guard toolsTab.exists else { return }
        toolsTab.tap()

        // Look for Ping tool link
        let pingLink = app.buttons["tool_link_ping"]
        if pingLink.waitForExistence(timeout: 5) {
            pingLink.tap()
            let pingScreen = app.otherElements["screen_pingTool"]
            XCTAssertTrue(pingScreen.waitForExistence(timeout: 5), "Ping tool screen should load")
        }
    }

    func testPortScannerToolNavigation() {
        let toolsTab = app.tabBars.buttons["Tools"]
        guard toolsTab.exists else { return }
        toolsTab.tap()

        let portScanLink = app.buttons["tool_link_portScanner"]
        if portScanLink.waitForExistence(timeout: 5) {
            portScanLink.tap()
            let portScanScreen = app.otherElements["screen_portScannerTool"]
            XCTAssertTrue(portScanScreen.waitForExistence(timeout: 5), "Port Scanner screen should load")
        }
    }
}
