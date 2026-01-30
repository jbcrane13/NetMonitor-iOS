import Testing
@testable import Netmonitor

@Suite("NetworkMonitorService Tests")
struct NetworkMonitorServiceTests {

    @Test("Service initializes and starts monitoring")
    func initialState() async {
        let service = await NetworkMonitorService()
        // Service starts monitoring on init, verify it doesn't crash
        let statusText = await service.statusText
        #expect(!statusText.isEmpty)
    }
}
