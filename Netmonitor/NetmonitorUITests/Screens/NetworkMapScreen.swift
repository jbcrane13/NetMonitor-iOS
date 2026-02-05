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
    
    var scanButton: XCUIElement {
        app.buttons["networkMap_button_scan"]
    }
    
    // MARK: - Navigation
    @discardableResult
    func navigateToNetworkMap() -> Self {
        navigateToTab("Map")
        _ = waitForElement(screen)
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
        waitForElement(screen)
    }
    
    func verifyTopologyPresent() -> Bool {
        waitForElement(topology)
    }
    
    func verifyGatewayNodePresent() -> Bool {
        waitForElement(gatewayNode)
    }
    
    func verifyDeviceListPresent() -> Bool {
        waitForElement(deviceList)
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
