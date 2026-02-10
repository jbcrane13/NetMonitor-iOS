import XCTest

/// UI tests for the Web Browser tool functionality
final class WebBrowserToolUITests: XCTestCase {

    var app: XCUIApplication!
    var webBrowserScreen: WebBrowserToolScreen!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        webBrowserScreen = toolsScreen.openWebBrowserTool()
    }

    override func tearDown() {
        app = nil
        webBrowserScreen = nil
        super.tearDown()
    }

    // MARK: - Screen Display Tests

    func testWebBrowserToolScreenDisplays() {
        XCTAssertTrue(webBrowserScreen.isDisplayed(), "Web Browser tool screen should be displayed")
    }

    func testURLInputFieldExists() {
        XCTAssertTrue(
            webBrowserScreen.urlInput.waitForExistence(timeout: 5),
            "URL input field should exist"
        )
    }

    func testOpenButtonExists() {
        XCTAssertTrue(
            webBrowserScreen.openButton.waitForExistence(timeout: 5),
            "Open URL button should exist"
        )
    }

    func testBookmarksSectionExists() {
        XCTAssertTrue(
            webBrowserScreen.bookmarksSection.waitForExistence(timeout: 5),
            "Bookmarks section should be visible"
        )
    }

    // MARK: - Input Tests

    func testCanEnterURL() {
        let testURL = "192.168.1.1"
        webBrowserScreen.enterURL(testURL)

        let fieldValue = webBrowserScreen.getURLFieldValue()
        XCTAssertEqual(fieldValue, testURL, "URL field should contain the entered text")
    }

    func testOpenButtonDisabledWhenEmpty() {
        // Open button should be disabled initially when URL field is empty
        XCTAssertFalse(
            webBrowserScreen.isOpenButtonEnabled(),
            "Open button should be disabled when URL field is empty"
        )
    }

    func testOpenButtonEnabledWhenURLEntered() {
        webBrowserScreen.enterURL("example.com")

        XCTAssertTrue(
            webBrowserScreen.isOpenButtonEnabled(),
            "Open button should be enabled when URL is entered"
        )
    }

    // MARK: - Bookmarks Tests

    func testBookmarkItemsExist() {
        // Verify at least the router admin bookmark exists
        XCTAssertTrue(
            webBrowserScreen.routerAdminBookmark.waitForExistence(timeout: 5),
            "Router Admin bookmark should exist"
        )
    }

    func testAllSixBookmarksExist() {
        // Verify all 6 bookmarks are present
        XCTAssertTrue(
            webBrowserScreen.routerAdminBookmark.waitForExistence(timeout: 5),
            "Router Admin bookmark should exist"
        )
        XCTAssertTrue(
            webBrowserScreen.speedTestBookmark.waitForExistence(timeout: 5),
            "Speed Test bookmark should exist"
        )
        XCTAssertTrue(
            webBrowserScreen.dnsCheckerBookmark.waitForExistence(timeout: 5),
            "DNS Checker bookmark should exist"
        )
        XCTAssertTrue(
            webBrowserScreen.whatIsMyIPBookmark.waitForExistence(timeout: 5),
            "What's My IP bookmark should exist"
        )
        XCTAssertTrue(
            webBrowserScreen.portCheckerBookmark.waitForExistence(timeout: 5),
            "Port Checker bookmark should exist"
        )
        XCTAssertTrue(
            webBrowserScreen.pingTestBookmark.waitForExistence(timeout: 5),
            "Ping Test bookmark should exist"
        )
    }

    // MARK: - Navigation Tests

    func testCanNavigateBack() {
        webBrowserScreen.navigateBack()

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }

    func testWebBrowserScreenHasNavigationTitle() {
        XCTAssertTrue(
            app.navigationBars["Web Browser"].waitForExistence(timeout: 5),
            "Web Browser navigation title should exist"
        )
    }

    func testRecentSectionHiddenInitially() {
        // Recent section should not be visible on first launch or should be empty
        let recentVisible = webBrowserScreen.recentSection.exists

        // If recent section exists, it should either be hidden or have no items
        if recentVisible {
            // Check if there are any recent items - there should be none initially
            let recentItems = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'webBrowser_recent_'"))
            XCTAssertEqual(recentItems.count, 0, "Recent section should be empty on first launch")
        } else {
            XCTAssertFalse(recentVisible, "Recent section should not be visible initially")
        }
    }
}
