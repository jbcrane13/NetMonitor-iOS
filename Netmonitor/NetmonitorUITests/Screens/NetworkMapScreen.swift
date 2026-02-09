import XCTest

/// Network Map screen page object
final class NetworkMapScreen: BaseScreen {
    
    // MARK: - Screen Identifier
    var screen: XCUIElement {
        app.otherElements["screen_networkMap"]
    }
    
    // MARK: - Elements
    var topology: XCUIElement {
        app.otherElements["networkMap_topology"]
    }

    var deviceList: XCUIElement {
        app.otherElements["networkMap_deviceList"]
    }

    var gatewayNode: XCUIElement {
        app.otherElements["networkMap_node_gateway"]
    }

    // Fallback text elements for when otherElements aren't found
    var devicesHeaderText: XCUIElement {
        app.staticTexts["Devices"]
    }

    var gatewayText: XCUIElement {
        app.staticTexts["Gateway"]
    }
    
    var scanButton: XCUIElement {
        app.buttons["networkMap_button_scan"]
    }
    
    // MARK: - Navigation
    @discardableResult
    func navigateToNetworkMap() -> Self {
        navigateToTab("Map")
        // Wait for a reliable button instead of screen container
        _ = waitForElement(scanButton)
        return self
    }
    
    // MARK: - Actions
    @discardableResult
    func startScan() -> Self {
        tapIfExists(scanButton)
        return self
    }
    
    // MARK: - Verification
    func isDisplayed() -> Bool {
        // Check for scan button instead of screen container for more reliable detection
        // Buttons become available faster than otherElements during navigation
        waitForElement(scanButton)
    }
    
    func verifyTopologyPresent() -> Bool {
        // Topology is a GeometryReader - try otherElements, fall back to gateway text
        waitForElement(topology) || waitForElement(gatewayText)
    }

    func verifyGatewayNodePresent() -> Bool {
        // Gateway node is a ZStack - try otherElements, fall back to gateway text
        waitForElement(gatewayNode) || waitForElement(gatewayText)
    }

    func verifyDeviceListPresent() -> Bool {
        // Device list section - try otherElements, fall back to "Devices" header text
        waitForElement(deviceList) || waitForElement(devicesHeaderText)
    }
    
    /// Get count of discovered device nodes
    func getDeviceNodeCount() -> Int {
        app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'networkMap_node_'")).count - 1 // Subtract gateway
    }
    
    /// Tap a device node by IP (underscored format)
    func tapDeviceNode(ip: String) {
        let nodeId = "networkMap_node_\(ip.replacingOccurrences(of: ".", with: "_"))"
        let node = app.otherElements[nodeId]
        tapIfExists(node)
    }
}
