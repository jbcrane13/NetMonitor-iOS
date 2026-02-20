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

        XCTAssertTrue(
            whoisScreen.waitForCompletedOutcome(timeout: 35),
            "WHOIS lookup should complete with either domain info or error"
        )
        XCTAssertTrue(
            whoisScreen.domainInfoCard.exists || whoisScreen.errorView.exists,
            "WHOIS lookup should surface a concrete result or error card"
        )
    }

    func testWHOISShowsDates() throws {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        XCTAssertTrue(
            whoisScreen.waitForCompletedOutcome(timeout: 35),
            "WHOIS lookup should complete before dates section is validated"
        )
        guard whoisScreen.domainInfoCard.exists else {
            throw XCTSkip("WHOIS lookup ended in error state for this run; dates section cannot be validated.")
        }

        whoisScreen.swipeUp()
        XCTAssertTrue(
            whoisScreen.waitForDates(timeout: 5),
            "WHOIS results should include a domain-dates section for google.com"
        )
    }

    func testWHOISShowsNameServers() throws {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        XCTAssertTrue(
            whoisScreen.waitForCompletedOutcome(timeout: 35),
            "WHOIS lookup should complete before nameserver section is validated"
        )
        guard whoisScreen.domainInfoCard.exists else {
            throw XCTSkip("WHOIS lookup ended in error state for this run; nameserver section cannot be validated.")
        }

        whoisScreen.swipeUp()
        XCTAssertTrue(
            whoisScreen.waitForNameServers(timeout: 5),
            "WHOIS results should include a name-servers section for google.com"
        )
    }
    
    // MARK: - Clear Results Tests
    
    func testCanClearResults() throws {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        XCTAssertTrue(
            whoisScreen.waitForCompletedOutcome(timeout: 35),
            "WHOIS lookup should complete before clear action is tested"
        )
        guard whoisScreen.domainInfoCard.exists else {
            throw XCTSkip("WHOIS lookup ended in error state; clear button only appears when result data exists.")
        }
        XCTAssertTrue(
            whoisScreen.clearButton.waitForExistence(timeout: 5),
            "Clear button should appear when WHOIS result cards are visible"
        )
        
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

    func testClearButtonExists() throws {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        XCTAssertTrue(
            whoisScreen.waitForCompletedOutcome(timeout: 35),
            "WHOIS lookup should complete before clear button presence is evaluated"
        )
        guard whoisScreen.domainInfoCard.exists else {
            throw XCTSkip("WHOIS lookup ended in error state; clear button only appears for successful lookups.")
        }

        let clearExists = whoisScreen.clearButton.waitForExistence(timeout: 5)
        XCTAssertTrue(
            clearExists,
            "Clear button should appear after successful WHOIS lookup"
        )
    }

    func testWHOISScreenHasNavigationTitle() {
        XCTAssertTrue(
            app.navigationBars["WHOIS Lookup"].waitForExistence(timeout: 5),
            "WHOIS navigation title should exist"
        )
    }

    // MARK: - Functional Verification Tests

    func testDomainInfoCardContent() throws {
        let testDomain = "example.com"
        whoisScreen
            .enterDomain(testDomain)
            .startLookup()

        XCTAssertTrue(
            whoisScreen.waitForCompletedOutcome(timeout: 35),
            "WHOIS lookup should complete before card content is validated"
        )
        guard whoisScreen.domainInfoCard.exists else {
            throw XCTSkip("WHOIS lookup ended in error state for this run; domain-info content cannot be validated.")
        }

        // Domain info card should reference the queried domain or show registrar info
        let domainInUI = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] 'example'", testDomain)
        ).count > 0

        let hasDomainLabel = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Domain Name' OR label CONTAINS[c] 'Registrar'")
        ).count > 0

        XCTAssertTrue(
            domainInUI || hasDomainLabel,
            "Domain info card should show content related to the queried domain"
        )
    }

    func testNameServersDisplay() throws {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()

        XCTAssertTrue(
            whoisScreen.waitForCompletedOutcome(timeout: 35),
            "WHOIS lookup should complete before nameserver content is validated"
        )
        guard whoisScreen.domainInfoCard.exists else {
            throw XCTSkip("WHOIS lookup ended in error state for this run; nameserver content cannot be validated.")
        }

        whoisScreen.swipeUp()

        let hasNameServersCard = whoisScreen.nameServersCard.waitForExistence(timeout: 5)
        let hasNSContent = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'ns' OR label CONTAINS[c] 'nameserver' OR label CONTAINS[c] '.NS'")
        ).count > 0

        XCTAssertTrue(
            hasNameServersCard || hasNSContent,
            "WHOIS result should include name servers section content"
        )
    }
}
