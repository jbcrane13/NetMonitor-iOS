import XCTest

/// UI tests for the DNS Lookup tool functionality
final class DNSLookupToolUITests: XCTestCase {
    
    var app: XCUIApplication!
    var dnsScreen: DNSLookupToolScreen!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        let toolsScreen = ToolsScreen(app: app)
        toolsScreen.navigateToTools()
        dnsScreen = toolsScreen.openDNSLookupTool()
    }
    
    override func tearDown() {
        app = nil
        dnsScreen = nil
        super.tearDown()
    }
    
    // MARK: - Screen Display Tests
    
    func testDNSLookupToolScreenDisplays() {
        XCTAssertTrue(dnsScreen.isDisplayed(), "DNS Lookup tool screen should be displayed")
    }
    
    func testDomainInputFieldExists() {
        XCTAssertTrue(
            dnsScreen.domainInput.waitForExistence(timeout: 5),
            "Domain input field should exist"
        )
    }
    
    func testRecordTypePickerExists() {
        XCTAssertTrue(
            dnsScreen.recordTypePicker.waitForExistence(timeout: 5),
            "Record type picker should exist"
        )
    }
    
    func testRunButtonExists() {
        XCTAssertTrue(
            dnsScreen.runButton.waitForExistence(timeout: 5),
            "Run button should exist"
        )
    }
    
    // MARK: - Input Tests
    
    func testCanEnterDomain() {
        dnsScreen.enterDomain("example.com")
        
        XCTAssertEqual(
            dnsScreen.domainInput.value as? String,
            "example.com",
            "Domain input should contain entered text"
        )
    }
    
    // MARK: - Execution Tests
    
    func testCanPerformDNSLookup() {
        dnsScreen
            .enterDomain("google.com")
            .startLookup()
        
        XCTAssertTrue(
            dnsScreen.waitForQueryInfo(timeout: 15),
            "DNS lookup should show query info"
        )
    }
    
    func testDNSLookupShowsRecords() {
        dnsScreen
            .enterDomain("google.com")
            .startLookup()
        
        XCTAssertTrue(
            dnsScreen.waitForRecords(timeout: 15),
            "DNS lookup should show records"
        )
    }
    
    // MARK: - Clear Results Tests
    
    func testCanClearResults() {
        dnsScreen
            .enterDomain("google.com")
            .startLookup()
        
        _ = dnsScreen.waitForQueryInfo(timeout: 15)
        
        dnsScreen.clearResults()
        
        XCTAssertFalse(
            dnsScreen.queryInfoCard.exists,
            "Results should be cleared"
        )
    }
    
    // MARK: - Navigation Tests
    
    func testCanNavigateBack() {
        dnsScreen.navigateBack()
        
        let toolsScreen = ToolsScreen(app: app)
        XCTAssertTrue(toolsScreen.isDisplayed(), "Should return to Tools screen")
    }
}
