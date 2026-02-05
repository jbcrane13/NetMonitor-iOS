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
            whoisScreen.waitForDomainInfo(timeout: 15),
            "WHOIS lookup should show domain info"
        )
    }
    
    func testWHOISShowsDates() {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()
        
        _ = whoisScreen.waitForDomainInfo(timeout: 15)
        whoisScreen.swipeUp()
        
        XCTAssertTrue(
            whoisScreen.waitForDates(timeout: 5),
            "WHOIS should show domain dates"
        )
    }
    
    func testWHOISShowsNameServers() {
        whoisScreen
            .enterDomain("google.com")
            .startLookup()
        
        _ = whoisScreen.waitForDomainInfo(timeout: 15)
        whoisScreen.swipeUp()
        
        XCTAssertTrue(
            whoisScreen.waitForNameServers(timeout: 5),
            "WHOIS should show name servers"
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
}
