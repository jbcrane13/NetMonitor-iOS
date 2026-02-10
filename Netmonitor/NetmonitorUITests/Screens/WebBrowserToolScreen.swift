import XCTest

/// Web Browser Tool screen page object
final class WebBrowserToolScreen: BaseScreen {

    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.descendants(matching: .any)["screen_webBrowser"]
    }

    // MARK: - Input Elements
    var urlInput: XCUIElement {
        app.textFields["webBrowser_input_url"]
    }

    // MARK: - Control Buttons
    var openButton: XCUIElement {
        app.buttons["webBrowser_button_open"]
    }

    var clearRecentButton: XCUIElement {
        app.buttons["webBrowser_button_clearRecent"]
    }

    // MARK: - Sections
    var bookmarksSection: XCUIElement {
        app.descendants(matching: .any)["webBrowser_section_bookmarks"]
    }

    var recentSection: XCUIElement {
        app.descendants(matching: .any)["webBrowser_section_recent"]
    }

    // MARK: - Bookmarks
    var routerAdminBookmark: XCUIElement {
        app.buttons["webBrowser_bookmark_router_admin"]
    }

    var speedTestBookmark: XCUIElement {
        app.buttons["webBrowser_bookmark_speed_test"]
    }

    var dnsCheckerBookmark: XCUIElement {
        app.buttons["webBrowser_bookmark_dns_checker"]
    }

    var whatIsMyIPBookmark: XCUIElement {
        app.buttons["webBrowser_bookmark_what's_my_ip"]
    }

    var portCheckerBookmark: XCUIElement {
        app.buttons["webBrowser_bookmark_port_checker"]
    }

    var pingTestBookmark: XCUIElement {
        app.buttons["webBrowser_bookmark_ping_test"]
    }

    // MARK: - Verification
    func isDisplayed() -> Bool {
        openButton.waitForExistence(timeout: timeout)
    }

    // MARK: - Actions
    @discardableResult
    func enterURL(_ url: String) -> Self {
        if urlInput.waitForExistence(timeout: timeout) {
            urlInput.tap()
            urlInput.typeText(url)
        }
        return self
    }

    @discardableResult
    func clearURLField() -> Self {
        if urlInput.waitForExistence(timeout: timeout) {
            urlInput.tap()
            // Select all and delete
            urlInput.tap()
            urlInput.doubleTap()
            app.menuItems["Select All"].tap()
            app.keys["delete"].tap()
        }
        return self
    }

    @discardableResult
    func tapOpen() -> Self {
        tapIfExists(openButton)
        return self
    }

    @discardableResult
    func tapBookmark(_ bookmark: XCUIElement) -> Self {
        tapIfExists(bookmark)
        return self
    }

    @discardableResult
    func tapClearRecent() -> Self {
        tapIfExists(clearRecentButton)
        return self
    }

    func isOpenButtonEnabled() -> Bool {
        openButton.isEnabled
    }

    func getURLFieldValue() -> String {
        urlInput.value as? String ?? ""
    }

    /// Navigate back to Tools
    func navigateBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }
}
