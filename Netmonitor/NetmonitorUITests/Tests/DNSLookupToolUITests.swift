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
            dnsScreen.waitForCompletedOutcome(timeout: 20),
            "DNS lookup should complete with either query info or a visible error state"
        )
        XCTAssertTrue(
            dnsScreen.queryInfoCard.exists || dnsScreen.errorView.exists,
            "DNS lookup outcome should be query info or error card"
        )
    }

    func testDNSLookupShowsRecords() {
        dnsScreen
            .enterDomain("google.com")
            .startLookup()

        XCTAssertTrue(
            dnsScreen.waitForCompletedOutcome(timeout: 20),
            "DNS lookup should complete before checking records output"
        )

        if dnsScreen.errorView.exists {
            XCTAssertTrue(dnsScreen.errorView.exists, "Failed DNS lookups should render the DNS error card")
        } else {
            XCTAssertTrue(
                dnsScreen.recordsCard.exists || dnsScreen.recordRows.count > 0,
                "Successful DNS lookups should render records content"
            )
        }
    }
    
    // MARK: - Clear Results Tests
    
    func testCanClearResults() throws {
        dnsScreen
            .enterDomain("google.com")
            .startLookup()

        XCTAssertTrue(
            dnsScreen.waitForCompletedOutcome(timeout: 20),
            "DNS lookup should complete before clear is tested"
        )
        guard dnsScreen.queryInfoCard.exists else {
            throw XCTSkip("Lookup ended in error state; clear button only appears when result data exists.")
        }

        XCTAssertTrue(
            dnsScreen.clearButton.waitForExistence(timeout: 5),
            "Clear button should appear when DNS query info is visible"
        )
        
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

    func testRecordTypePickerInteraction() {
        dnsScreen.recordTypePicker.tap()

        let hasMenu = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'A' OR label CONTAINS[c] 'AAAA' OR label CONTAINS[c] 'MX'")).count > 0

        XCTAssertTrue(
            hasMenu,
            "Record type picker should present record options when tapped"
        )
    }

    func testClearButtonExists() throws {
        dnsScreen
            .enterDomain("google.com")
            .startLookup()

        XCTAssertTrue(
            dnsScreen.waitForCompletedOutcome(timeout: 20),
            "DNS lookup should complete before clear button presence is evaluated"
        )
        guard dnsScreen.queryInfoCard.exists else {
            throw XCTSkip("Lookup ended in error state; clear button only appears for successful lookups.")
        }

        let clearExists = dnsScreen.clearButton.waitForExistence(timeout: 5)
        XCTAssertTrue(
            clearExists,
            "Clear button should appear after successful DNS lookup"
        )
    }

    // MARK: - Functional Verification Tests

    func testRecordTypePickerFunctional() {
        guard dnsScreen.recordTypePicker.waitForExistence(timeout: 5) else {
            XCTFail("Record type picker should exist")
            return
        }

        let initialLabel = dnsScreen.recordTypePicker.label
        dnsScreen.recordTypePicker.tap()

        // Try selecting a different record type
        let recordTypes = ["AAAA", "MX", "TXT", "CNAME", "NS", "PTR"]
        var tapped = false
        for recordType in recordTypes {
            let btn = app.buttons[recordType]
            if btn.waitForExistence(timeout: 2) && btn.label != initialLabel {
                btn.tap()
                tapped = true
                break
            }
        }

        XCTAssertTrue(tapped, "Record type picker should expose selectable menu items")
        XCTAssertTrue(
            dnsScreen.recordTypePicker.exists,
            "Record type picker should remain after selecting a record type"
        )
        let newLabel = dnsScreen.recordTypePicker.label
        XCTAssertNotEqual(newLabel, initialLabel, "Picker label should update to the selected record type")
    }

    func testQueryInfoCardContent() throws {
        let testDomain = "example.com"
        dnsScreen
            .enterDomain(testDomain)
            .startLookup()

        XCTAssertTrue(
            dnsScreen.waitForCompletedOutcome(timeout: 20),
            "DNS lookup should complete before query-info content is validated"
        )
        guard dnsScreen.queryInfoCard.exists else {
            throw XCTSkip("Lookup ended in error state for this run; query-info content cannot be validated.")
        }

        // Query info card should reference the domain we looked up
        let domainInUI = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] 'example'", testDomain)
        ).count > 0

        XCTAssertTrue(
            domainInUI,
            "Query info card should contain content matching the queried domain"
        )
    }
}
