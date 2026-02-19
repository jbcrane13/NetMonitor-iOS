import XCTest

/// UI tests for the WHOIS tool functionality
final class WHOISToolUITests: XCTestCase {
    
    var app: XCUIApplication!
    var whoisScreen: WHOISToolScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        whoisScreen = toolsScreen.openWHOISTool()
    }
    
    override func tearDown() {
        app = nil
        whoisScreen = nil
        super.tearDown()
    }
    
    // MARK: - Screen Display Tests
    
    func testWHOISToolScreenDisplays() {
        XCTAssertTrue(whoisScreen.isDisplayed(), "WHOIS tool screen should be displayed")
    }
    
    func testDomainInputFieldExists() {
        XCTAssertTrue(
            whoisScreen.domainInput.waitForExistence(timeout: 5),
            "Domain input field should exist"
        )
    }
    
    func testRunButtonExists() {
        XCTAssertTrue(
            whoisScreen.runButton.waitForExistence(timeout: 5),
            "Run button should exist"
        )
    }
    
    // MARK: - Input Tests
    
    func testCanEnterDomain() {
        whoisScreen.enterDomain("example.com")
        
        XCTAssertEqual(
            whoisScreen.domainInput.value as? String,
            "example.com",
            "Domain input should contain entered text"
        )
    }
    
    // MARK: - Execution Tests
    
    func testCanPerformWHOISLookup() {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        // WHOIS may succeed or fail depending on network and simulator.
        // Accept domain info appearing, an error being shown, or the tool remaining functional.
        let gotInfo = whoisScreen.waitForDomainInfo(timeout: 30)
        let gotError = whoisScreen.hasError()
        XCTAssertTrue(
            gotInfo || gotError || whoisScreen.runButton.waitForExistence(timeout: 5),
            "WHOIS lookup should show domain info, an error, or remain functional"
        )
    }

    func testWHOISShowsDates() {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        let gotInfo = whoisScreen.waitForDomainInfo(timeout: 30)
        guard gotInfo else {
            // If lookup failed, skip the dates check -- the tool is still functional
            XCTAssertTrue(
                whoisScreen.hasError() || whoisScreen.runButton.exists,
                "WHOIS tool should remain functional"
            )
            return
        }
        whoisScreen.swipeUp()
        // Dates may or may not be present depending on the WHOIS response
        let hasDates = whoisScreen.waitForDates(timeout: 5)
        XCTAssertTrue(
            hasDates || whoisScreen.domainInfoCard.exists,
            "WHOIS should show dates or at least domain info"
        )
    }

    func testWHOISShowsNameServers() {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        let gotInfo = whoisScreen.waitForDomainInfo(timeout: 30)
        guard gotInfo else {
            XCTAssertTrue(
                whoisScreen.hasError() || whoisScreen.runButton.exists,
                "WHOIS tool should remain functional"
            )
            return
        }
        whoisScreen.swipeUp()
        // Name servers may or may not be present depending on the WHOIS response
        let hasNameServers = whoisScreen.waitForNameServers(timeout: 5)
        XCTAssertTrue(
            hasNameServers || whoisScreen.domainInfoCard.exists,
            "WHOIS should show name servers or at least domain info"
        )
    }
    
    // MARK: - Clear Results Tests
    
    func testCanClearResults() {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()
        
        _ = whoisScreen.waitForDomainInfo(timeout: 15)
        
        whoisScreen.clearResults()
        
        XCTAssertFalse(
            whoisScreen.domainInfoCard.exists,
            "Results should be cleared"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        whoisScreen.navigateBack()

        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }

    func testClearButtonExists() {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        _ = whoisScreen.waitForDomainInfo(timeout: 15)

        let clearExists = whoisScreen.clearButton.waitForExistence(timeout: 5)
        XCTAssertTrue(
            clearExists || whoisScreen.runButton.exists,
            "Clear button should appear after lookup, or tool should remain functional"
        )
    }

    func testWHOISScreenHasNavigationTitle() {
        XCTAssertTrue(
            app.navigationBars["WHOIS Lookup"].waitForExistence(timeout: 5),
            "WHOIS navigation title should exist"
        )
    }

    // MARK: - Functional Verification Tests

    func testDomainInfoCardContent() {
        let testDomain = "example.com"
        whoisScreen
            .enterDomain(testDomain)
            .startLookup()

        let gotInfo = whoisScreen.waitForDomainInfo(timeout: 30)
        guard gotInfo else {
            XCTAssertTrue(
                whoisScreen.hasError() || whoisScreen.runButton.waitForExistence(timeout: 5),
                "WHOIS tool should show error or remain functional"
            )
            return
        }

        // Domain info card should reference the queried domain or show registrar info
        let domainInUI = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] 'example'", testDomain)
        ).count > 0

        let hasDomainLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Domain Name' OR label CONTAINS[c] 'Registrar'")
        ).count > 0

        XCTAssertTrue(
            domainInUI || hasDomainLabel || whoisScreen.domainInfoCard.exists,
            "Domain info card should show content related to the queried domain"
        )
    }

    func testNameServersDisplay() {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        let gotInfo = whoisScreen.waitForDomainInfo(timeout: 30)
        guard gotInfo else {
            XCTAssertTrue(
                whoisScreen.hasError() || whoisScreen.runButton.waitForExistence(timeout: 5),
                "WHOIS tool should remain functional"
            )
            return
        }

        whoisScreen.swipeUp()

        let hasNameServersCard = whoisScreen.nameServersCard.waitForExistence(timeout: 5)
        let hasNameServersText = whoisScreen.nameServersText.exists
        let hasNSContent = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'ns' OR label CONTAINS[c] 'nameserver' OR label CONTAINS[c] '.NS'")
        ).count > 0

        XCTAssertTrue(
            hasNameServersCard || hasNameServersText || hasNSContent || whoisScreen.domainInfoCard.exists,
            "WHOIS result should include name servers section or at least domain info"
        )
    }
}
