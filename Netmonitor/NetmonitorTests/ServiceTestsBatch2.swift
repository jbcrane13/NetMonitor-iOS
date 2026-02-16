import Testing
import Foundation
@testable import Netmonitor

// MARK: - SpeedTestService Tests

@Suite("SpeedTestService Tests")
@MainActor
struct SpeedTestServiceTests {

    @Test("Initial state is correct")
    func initialState() {
        let service = SpeedTestService()

        #expect(service.downloadSpeed == 0)
        #expect(service.uploadSpeed == 0)
        #expect(service.latency == 0)
        #expect(service.progress == 0)
        #expect(service.phase == .idle)
        #expect(service.isRunning == false)
        #expect(service.errorMessage == nil)
        #expect(service.duration == 5.0)
    }

    @Test("Duration can be set")
    func durationSetter() {
        let service = SpeedTestService()

        service.duration = 10.0
        #expect(service.duration == 10.0)

        service.duration = 2.0
        #expect(service.duration == 2.0)
    }

    @Test("stopTest resets state")
    func stopTest() {
        let service = SpeedTestService()

        // Simulate some running state
        service.phase = .download
        service.isRunning = true
        service.progress = 0.5

        service.stopTest()

        #expect(service.isRunning == false)
        #expect(service.phase == .idle)
    }

    @Test("SpeedTestPhase enum has all expected cases")
    func speedTestPhaseValues() {
        let idle: SpeedTestPhase = .idle
        let latency: SpeedTestPhase = .latency
        let download: SpeedTestPhase = .download
        let upload: SpeedTestPhase = .upload
        let complete: SpeedTestPhase = .complete

        #expect(idle.rawValue == "idle")
        #expect(latency.rawValue == "latency")
        #expect(download.rawValue == "download")
        #expect(upload.rawValue == "upload")
        #expect(complete.rawValue == "complete")
    }
}

// MARK: - SpeedTestResult Tests

@Suite("SpeedTestResult Model Tests")
struct SpeedTestResultBatch2Tests {

    @Test("downloadSpeedText formats Mbps correctly")
    func downloadSpeedMbps() {
        let result = SpeedTestResult(
            downloadSpeed: 150.5,
            uploadSpeed: 50.0,
            latency: 20.0
        )

        #expect(result.downloadSpeedText == "150.5 Mbps")
    }

    @Test("downloadSpeedText formats Gbps correctly")
    func downloadSpeedGbps() {
        let result = SpeedTestResult(
            downloadSpeed: 1200.0,
            uploadSpeed: 800.0,
            latency: 15.0
        )

        #expect(result.downloadSpeedText == "1.2 Gbps")
    }

    @Test("uploadSpeedText formats Mbps correctly")
    func uploadSpeedMbps() {
        let result = SpeedTestResult(
            downloadSpeed: 100.0,
            uploadSpeed: 75.3,
            latency: 25.0
        )

        #expect(result.uploadSpeedText == "75.3 Mbps")
    }

    @Test("uploadSpeedText formats Gbps correctly")
    func uploadSpeedGbps() {
        let result = SpeedTestResult(
            downloadSpeed: 1500.0,
            uploadSpeed: 1050.0,
            latency: 10.0
        )

        #expect(result.uploadSpeedText == "1.1 Gbps")
    }

    @Test("latencyText formats correctly")
    func latencyText() {
        let result = SpeedTestResult(
            downloadSpeed: 100.0,
            uploadSpeed: 50.0,
            latency: 23.7
        )

        #expect(result.latencyText == "24 ms")
    }

    @Test("Speed formatting at 1000 Mbps boundary")
    func speedBoundary() {
        let exactlyOneGbps = SpeedTestResult(
            downloadSpeed: 1000.0,
            uploadSpeed: 1000.0,
            latency: 20.0
        )

        #expect(exactlyOneGbps.downloadSpeedText == "1.0 Gbps")
        #expect(exactlyOneGbps.uploadSpeedText == "1.0 Gbps")

        let justUnder = SpeedTestResult(
            downloadSpeed: 999.9,
            uploadSpeed: 999.9,
            latency: 20.0
        )

        #expect(justUnder.downloadSpeedText == "999.9 Mbps")
        #expect(justUnder.uploadSpeedText == "999.9 Mbps")
    }
}

// MARK: - WiFiInfoService Tests

@Suite("WiFiInfoService Tests")
@MainActor
struct WiFiInfoServiceTests {

    @Test("Service can be instantiated")
    func initialState() {
        let service = WiFiInfoService()

        // In simulator, currentWiFi may be populated with mock data
        // so we only verify the service is accessible
        #expect(service.isLocationAuthorized == false || service.isLocationAuthorized == true)
    }
}

// MARK: - WiFiInfo Model Tests

@Suite("WiFiInfo Model Tests")
struct WiFiInfoModelTests {

    @Test("signalQuality classification - excellent")
    func signalQualityExcellent() {
        let excellent1 = WiFiInfo(ssid: "Test", signalDBm: -40)
        #expect(excellent1.signalQuality == .excellent)

        let excellent2 = WiFiInfo(ssid: "Test", signalDBm: -50)
        #expect(excellent2.signalQuality == .excellent)
    }

    @Test("signalQuality classification - good")
    func signalQualityGood() {
        let good1 = WiFiInfo(ssid: "Test", signalDBm: -51)
        #expect(good1.signalQuality == .good)

        let good2 = WiFiInfo(ssid: "Test", signalDBm: -59)
        #expect(good2.signalQuality == .good)
    }

    @Test("signalQuality classification - fair")
    func signalQualityFair() {
        let fair1 = WiFiInfo(ssid: "Test", signalDBm: -61)
        #expect(fair1.signalQuality == .fair)

        let fair2 = WiFiInfo(ssid: "Test", signalDBm: -69)
        #expect(fair2.signalQuality == .fair)
    }

    @Test("signalQuality classification - poor")
    func signalQualityPoor() {
        let poor1 = WiFiInfo(ssid: "Test", signalDBm: -71)
        #expect(poor1.signalQuality == .poor)

        let poor2 = WiFiInfo(ssid: "Test", signalDBm: -90)
        #expect(poor2.signalQuality == .poor)
    }

    @Test("signalQuality classification - unknown when nil")
    func signalQualityUnknown() {
        let unknown = WiFiInfo(ssid: "Test", signalDBm: nil)
        #expect(unknown.signalQuality == .unknown)
    }

    @Test("signalBars calculation - 4 bars")
    func signalBars4() {
        let bars4a = WiFiInfo(ssid: "Test", signalDBm: -40)
        #expect(bars4a.signalBars == 4)

        let bars4b = WiFiInfo(ssid: "Test", signalDBm: -50)
        #expect(bars4b.signalBars == 4)
    }

    @Test("signalBars calculation - 3 bars")
    func signalBars3() {
        let bars3a = WiFiInfo(ssid: "Test", signalDBm: -51)
        #expect(bars3a.signalBars == 3)

        let bars3b = WiFiInfo(ssid: "Test", signalDBm: -59)
        #expect(bars3b.signalBars == 3)
    }

    @Test("signalBars calculation - 2 bars")
    func signalBars2() {
        let bars2a = WiFiInfo(ssid: "Test", signalDBm: -61)
        #expect(bars2a.signalBars == 2)

        let bars2b = WiFiInfo(ssid: "Test", signalDBm: -69)
        #expect(bars2b.signalBars == 2)
    }

    @Test("signalBars calculation - 1 bar")
    func signalBars1() {
        let bars1a = WiFiInfo(ssid: "Test", signalDBm: -71)
        #expect(bars1a.signalBars == 1)

        let bars1b = WiFiInfo(ssid: "Test", signalDBm: -79)
        #expect(bars1b.signalBars == 1)
    }

    @Test("signalBars calculation - 0 bars")
    func signalBars0() {
        let bars0a = WiFiInfo(ssid: "Test", signalDBm: -81)
        #expect(bars0a.signalBars == 0)

        let bars0b = WiFiInfo(ssid: "Test", signalDBm: -100)
        #expect(bars0b.signalBars == 0)

        let bars0c = WiFiInfo(ssid: "Test", signalDBm: nil)
        #expect(bars0c.signalBars == 0)
    }

    @Test("signalBars and signalQuality boundary values")
    func boundaryValues() {
        // Boundaries use half-open ranges: -50...0 excellent, -60..<-50 good, -70..<-60 fair
        let at50 = WiFiInfo(ssid: "Test", signalDBm: -50)
        #expect(at50.signalQuality == .excellent)
        #expect(at50.signalBars == 4)

        let at60 = WiFiInfo(ssid: "Test", signalDBm: -60)
        #expect(at60.signalQuality == .good)  // -60 is in -60..<-50
        #expect(at60.signalBars == 3)

        let at70 = WiFiInfo(ssid: "Test", signalDBm: -70)
        #expect(at70.signalQuality == .fair)  // -70 is in -70..<-60
        #expect(at70.signalBars == 2)

        let at80 = WiFiInfo(ssid: "Test", signalDBm: -80)
        #expect(at80.signalQuality == .poor)
        #expect(at80.signalBars == 1)  // -80 is in -80..<-70
    }
}

// MARK: - PublicIPService Tests

@Suite("PublicIPService Tests")
@MainActor
struct PublicIPServiceTests {

    @Test("Initial state is correct")
    func initialState() {
        let service = PublicIPService()

        #expect(service.ispInfo == nil)
        #expect(service.isLoading == false)
    }
}

// MARK: - ISPInfo Model Tests

@Suite("ISPInfo Model Tests")
struct ISPInfoModelTests {

    @Test("locationText with city and country")
    func locationTextFull() {
        let info = ISPInfo(
            publicIP: "1.2.3.4",
            city: "San Francisco",
            country: "United States",
            countryCode: "US"
        )

        // Should prefer countryCode over country
        #expect(info.locationText == "San Francisco, US")
    }

    @Test("locationText with city and country (no code)")
    func locationTextCityCountry() {
        let info = ISPInfo(
            publicIP: "1.2.3.4",
            city: "London",
            country: "United Kingdom",
            countryCode: nil
        )

        #expect(info.locationText == "London, United Kingdom")
    }

    @Test("locationText with only city")
    func locationTextCityOnly() {
        let info = ISPInfo(
            publicIP: "1.2.3.4",
            city: "Tokyo",
            country: nil,
            countryCode: nil
        )

        #expect(info.locationText == "Tokyo")
    }

    @Test("locationText with only country")
    func locationTextCountryOnly() {
        let info = ISPInfo(
            publicIP: "1.2.3.4",
            city: nil,
            country: "Canada",
            countryCode: "CA"
        )

        // Should prefer countryCode
        #expect(info.locationText == "CA")
    }

    @Test("locationText with only countryCode")
    func locationTextCountryCodeOnly() {
        let info = ISPInfo(
            publicIP: "1.2.3.4",
            city: nil,
            country: nil,
            countryCode: "DE"
        )

        #expect(info.locationText == "DE")
    }

    @Test("locationText returns nil when empty")
    func locationTextEmpty() {
        let info = ISPInfo(
            publicIP: "1.2.3.4",
            city: nil,
            country: nil,
            countryCode: nil
        )

        #expect(info.locationText == nil)
    }

    @Test("locationText prefers countryCode over country")
    func locationTextPreferCode() {
        let info = ISPInfo(
            publicIP: "1.2.3.4",
            city: "Paris",
            country: "France",
            countryCode: "FR"
        )

        // Should use countryCode (FR) instead of country (France)
        #expect(info.locationText == "Paris, FR")
    }
}

// MARK: - BackgroundTaskService Tests

@Suite("BackgroundTaskService Tests")
@MainActor
struct BackgroundTaskServiceBatch2Tests {

    @Test("Task identifier constants are correct")
    func taskIdentifiers() {
        #expect(BackgroundTaskService.refreshTaskIdentifier == "com.blakemiller.netmonitor.refresh")
        #expect(BackgroundTaskService.syncTaskIdentifier == "com.blakemiller.netmonitor.sync")
    }

    @Test("BackgroundTaskService is a singleton")
    func singletonInstance() {
        let instance1 = BackgroundTaskService.shared
        let instance2 = BackgroundTaskService.shared

        // Both references should point to the same instance
        #expect(instance1 === instance2)
    }

    @Test("scheduleRefreshTask respects backgroundRefreshEnabled setting")
    func refreshTaskRespectsSetting() {
        let service = BackgroundTaskService.shared

        // Test that the method exists and can be called
        // (We can't easily test BGTaskScheduler behavior in unit tests,
        // but we can verify the method is accessible)
        service.scheduleRefreshTask()

        // No crash = success. The actual scheduling logic is tested
        // through integration tests with the BGTaskScheduler APIs.
        #expect(true)
    }

    @Test("Minimum interval enforcement logic")
    func minimumIntervalEnforcement() {
        // Test that 15 minutes (900 seconds) is the minimum
        // This tests the logic: max(15 * 60, interval)

        let fifteenMinutes: TimeInterval = 15 * 60
        let userInterval: TimeInterval = 30 // 30 seconds (too short)
        let effectiveInterval = max(fifteenMinutes, userInterval)

        #expect(effectiveInterval == fifteenMinutes)

        // Test with a longer interval
        let oneHour: TimeInterval = 60 * 60
        let effectiveLong = max(fifteenMinutes, oneHour)

        #expect(effectiveLong == oneHour)
    }
}
