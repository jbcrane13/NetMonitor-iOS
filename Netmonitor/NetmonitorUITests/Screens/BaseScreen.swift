import XCTest

/// Base screen class providing common UI testing utilities
class BaseScreen {
    let app: XCUIApplication
    let timeout: TimeInterval
    
    init(app: XCUIApplication, timeout: TimeInterval = 5.0) {
        self.app = app
        self.timeout = timeout
    }
    
    /// Wait for an element to exist
    @discardableResult
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval? = nil) -> Bool {
        element.waitForExistence(timeout: timeout ?? self.timeout)
    }
    
    /// Tap an element if it exists
    @discardableResult
    func tapIfExists(_ element: XCUIElement) -> Bool {
        if element.waitForExistence(timeout: timeout) {
            element.tap()
            return true
        }
        return false
    }
    
    /// Type text into a text field
    func typeText(_ element: XCUIElement, text: String) {
        if element.waitForExistence(timeout: timeout) {
            element.tap()
            element.typeText(text)
        }
    }
    
    /// Clear and type text
    func clearAndTypeText(_ element: XCUIElement, text: String) {
        if element.waitForExistence(timeout: timeout) {
            element.tap()
            // Select all and delete
            if let currentText = element.value as? String, !currentText.isEmpty {
                element.tap()
                element.press(forDuration: 1.2) // Long press to select
                app.menuItems["Select All"].tap()
                element.typeText(XCUIKeyboardKey.delete.rawValue)
            }
            element.typeText(text)
        }
    }
    
    /// Swipe up on element
    func swipeUp(on element: XCUIElement? = nil) {
        (element ?? app).swipeUp()
    }
    
    /// Swipe down on element
    func swipeDown(on element: XCUIElement? = nil) {
        (element ?? app).swipeDown()
    }

    /// Aggressively scroll to top of the current view
    func scrollToTop() {
        // Tap the status bar to trigger iOS scroll-to-top behavior
        let statusBar = app.statusBars.firstMatch
        if statusBar.exists {
            statusBar.tap()
            usleep(500_000) // 0.5 seconds for scroll animation
        } else {
            // Fallback: tap the top of the screen coordinate
            let topCoordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
            topCoordinate.tap()
            usleep(500_000)
        }
    }
    
    /// Dismiss keyboard if visible
    func dismissKeyboard() {
        if app.keyboards.count > 0 {
            app.keyboards.buttons["Return"].tap()
        }
    }
    
    /// Navigate to tab by name
    func navigateToTab(_ tabName: String) {
        let tab = app.tabBars.buttons[tabName]
        if tab.waitForExistence(timeout: timeout) {
            tab.tap()
        }
    }
}
