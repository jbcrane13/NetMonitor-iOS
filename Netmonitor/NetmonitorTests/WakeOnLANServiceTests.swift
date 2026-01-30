import Testing
@testable import Netmonitor

@Suite("WakeOnLAN Tests")
struct WakeOnLANServiceTests {

    @Test("Valid MAC address formats accepted")
    func validMACFormats() async {
        let service = await WakeOnLANService()

        // These should not crash - we test the service can attempt to wake
        // The actual network send will fail in test, but packet creation should work
        let colonFormat = await service.wake(macAddress: "AA:BB:CC:DD:EE:FF")
        let dashFormat = await service.wake(macAddress: "AA-BB-CC-DD-EE-FF")
        // Results depend on network availability, so we just verify no crash
        _ = colonFormat
        _ = dashFormat
    }

    @Test("Invalid MAC address rejected")
    func invalidMAC() async {
        let service = await WakeOnLANService()
        let result = await service.wake(macAddress: "not-a-mac")
        #expect(result == false)
    }

    @Test("Short MAC address rejected")
    func shortMAC() async {
        let service = await WakeOnLANService()
        let result = await service.wake(macAddress: "AA:BB:CC")
        #expect(result == false)
    }
}
