import Testing
@testable import Netmonitor

@Suite("DNSLookupService Tests")
struct DNSLookupServiceTests {

    @Test("Service initializes with nil state")
    func initialState() async {
        let service = await DNSLookupService()
        let isLoading = await service.isLoading
        let lastResult = await service.lastResult
        let lastError = await service.lastError

        #expect(isLoading == false)
        #expect(lastResult == nil)
        #expect(lastError == nil)
    }
}
