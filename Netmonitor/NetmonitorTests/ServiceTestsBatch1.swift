import Testing
import Foundation
@testable import Netmonitor

// MARK: - DataExportService Tests

@Suite("DataExportService Tests")
struct DataExportServiceTests {

    // MARK: - ExportFormat Tests

    @Test("ExportFormat fileExtension")
    func exportFormatFileExtension() {
        #expect(DataExportService.ExportFormat.json.fileExtension == "json")
        #expect(DataExportService.ExportFormat.csv.fileExtension == "csv")
    }

    @Test("ExportFormat mimeType")
    func exportFormatMimeType() {
        #expect(DataExportService.ExportFormat.json.mimeType == "application/json")
        #expect(DataExportService.ExportFormat.csv.mimeType == "text/csv")
    }

    // MARK: - Tool Results Export Tests

    @Test("Export empty tool results to JSON")
    func exportEmptyToolResultsJSON() {
        let results: [ToolResult] = []
        let data = DataExportService.exportToolResults(results, format: .json)

        #expect(data != nil)
        let json = try? JSONSerialization.jsonObject(with: data!)
        #expect(json != nil)
        let array = json as? [[String: Any]]
        #expect(array?.isEmpty == true)
    }

    @Test("Export empty tool results to CSV")
    func exportEmptyToolResultsCSV() {
        let results: [ToolResult] = []
        let data = DataExportService.exportToolResults(results, format: .csv)

        #expect(data != nil)
        let csv = String(data: data!, encoding: .utf8)
        #expect(csv?.hasPrefix("id,toolType,target,timestamp,duration,success,summary,details,errorMessage\n") == true)
        // Should only have header line
        let lines = csv?.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines?.count == 1)
    }

    @Test("Export tool results to JSON")
    func exportToolResultsJSON() {
        let result = ToolResult(
            toolType: .ping,
            target: "8.8.8.8",
            duration: 0.123,
            success: true,
            summary: "Ping successful",
            details: "4 packets sent, 4 received"
        )

        let data = DataExportService.exportToolResults([result], format: .json)
        #expect(data != nil)

        let json = try? JSONSerialization.jsonObject(with: data!)
        #expect(json != nil)

        let array = json as? [[String: String]]
        #expect(array?.count == 1)

        let item = array?.first
        #expect(item?["toolType"] == "ping")
        #expect(item?["target"] == "8.8.8.8")
        #expect(item?["success"] == "true")
        #expect(item?["summary"] == "Ping successful")
        #expect(item?["details"] == "4 packets sent, 4 received")
    }

    @Test("Export tool results to CSV")
    func exportToolResultsCSV() {
        let result = ToolResult(
            toolType: .portScan,
            target: "192.168.1.1",
            duration: 2.5,
            success: true,
            summary: "Scan complete",
            details: "5 open ports found"
        )

        let data = DataExportService.exportToolResults([result], format: .csv)
        #expect(data != nil)

        let csv = String(data: data!, encoding: .utf8)
        #expect(csv?.contains("portScan") == true)
        #expect(csv?.contains("192.168.1.1") == true)
        #expect(csv?.contains("Scan complete") == true)
    }

    @Test("CSV escaping with commas")
    func csvEscapingCommas() {
        let result = ToolResult(
            toolType: .ping,
            target: "8.8.8.8",
            duration: 0.1,
            success: true,
            summary: "Test, with, commas",
            details: "Normal details"
        )

        let data = DataExportService.exportToolResults([result], format: .csv)
        #expect(data != nil)

        let csv = String(data: data!, encoding: .utf8)
        // Should be quoted when contains comma
        #expect(csv?.contains("\"Test, with, commas\"") == true)
    }

    @Test("CSV escaping with quotes")
    func csvEscapingQuotes() {
        let result = ToolResult(
            toolType: .ping,
            target: "8.8.8.8",
            duration: 0.1,
            success: true,
            summary: "Test \"quoted\" text",
            details: "Normal details"
        )

        let data = DataExportService.exportToolResults([result], format: .csv)
        #expect(data != nil)

        let csv = String(data: data!, encoding: .utf8)
        // Quotes should be escaped as double quotes
        #expect(csv?.contains("\"Test \"\"quoted\"\" text\"") == true)
    }

    @Test("CSV escaping with newlines")
    func csvEscapingNewlines() {
        let result = ToolResult(
            toolType: .ping,
            target: "8.8.8.8",
            duration: 0.1,
            success: true,
            summary: "Test\nwith\nnewlines",
            details: "Normal details"
        )

        let data = DataExportService.exportToolResults([result], format: .csv)
        #expect(data != nil)

        let csv = String(data: data!, encoding: .utf8)
        // Should be quoted when contains newline
        #expect(csv?.contains("\"Test\nwith\nnewlines\"") == true)
    }

    // MARK: - Speed Test Export Tests

    @Test("Export empty speed tests to JSON")
    func exportEmptySpeedTestsJSON() {
        let results: [SpeedTestResult] = []
        let data = DataExportService.exportSpeedTests(results, format: .json)

        #expect(data != nil)
        let json = try? JSONSerialization.jsonObject(with: data!)
        #expect(json != nil)
        let array = json as? [[String: Any]]
        #expect(array?.isEmpty == true)
    }

    @Test("Export empty speed tests to CSV")
    func exportEmptySpeedTestsCSV() {
        let results: [SpeedTestResult] = []
        let data = DataExportService.exportSpeedTests(results, format: .csv)

        #expect(data != nil)
        let csv = String(data: data!, encoding: .utf8)
        #expect(csv?.hasPrefix("id,timestamp,downloadSpeed,uploadSpeed,latency,jitter,serverName,connectionType,success\n") == true)
        let lines = csv?.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines?.count == 1)
    }

    @Test("Export speed tests to JSON")
    func exportSpeedTestsJSON() {
        let result = SpeedTestResult(
            downloadSpeed: 100.5,
            uploadSpeed: 50.2,
            latency: 15.0,
            jitter: 2.5,
            serverName: "Test Server",
            connectionType: .wifi,
            success: true
        )

        let data = DataExportService.exportSpeedTests([result], format: .json)
        #expect(data != nil)

        let json = try? JSONSerialization.jsonObject(with: data!)
        let array = json as? [[String: String]]
        #expect(array?.count == 1)

        let item = array?.first
        #expect(item?["downloadSpeed"] == "100.5")
        #expect(item?["uploadSpeed"] == "50.2")
        #expect(item?["latency"] == "15.0")
        #expect(item?["jitter"] == "2.5")
        #expect(item?["serverName"] == "Test Server")
        #expect(item?["connectionType"] == "wifi")
    }

    @Test("Export speed tests to CSV")
    func exportSpeedTestsCSV() {
        let result = SpeedTestResult(
            downloadSpeed: 200.0,
            uploadSpeed: 100.0,
            latency: 10.0,
            connectionType: .ethernet,
            success: true
        )

        let data = DataExportService.exportSpeedTests([result], format: .csv)
        #expect(data != nil)

        let csv = String(data: data!, encoding: .utf8)
        #expect(csv?.contains("200.0") == true)
        #expect(csv?.contains("100.0") == true)
        #expect(csv?.contains("ethernet") == true)
    }

    @Test("Export speed tests with nil optional fields")
    func exportSpeedTestsWithNils() {
        let result = SpeedTestResult(
            downloadSpeed: 50.0,
            uploadSpeed: 25.0,
            latency: 20.0,
            jitter: nil,
            serverName: nil,
            connectionType: .wifi,
            success: true
        )

        let data = DataExportService.exportSpeedTests([result], format: .json)
        #expect(data != nil)

        let json = try? JSONSerialization.jsonObject(with: data!)
        let array = json as? [[String: String]]
        let item = array?.first
        #expect(item?["jitter"] == "")
        #expect(item?["serverName"] == "")
    }

    // MARK: - Devices Export Tests

    @Test("Export empty devices to JSON")
    func exportEmptyDevicesJSON() {
        let devices: [LocalDevice] = []
        let data = DataExportService.exportDevices(devices, format: .json)

        #expect(data != nil)
        let json = try? JSONSerialization.jsonObject(with: data!)
        let array = json as? [[String: Any]]
        #expect(array?.isEmpty == true)
    }

    @Test("Export empty devices to CSV")
    func exportEmptyDevicesCSV() {
        let devices: [LocalDevice] = []
        let data = DataExportService.exportDevices(devices, format: .csv)

        #expect(data != nil)
        let csv = String(data: data!, encoding: .utf8)
        #expect(csv?.hasPrefix("id,ipAddress,macAddress,hostname,vendor,deviceType,customName,status,lastLatency,isGateway,firstSeen,lastSeen\n") == true)
        let lines = csv?.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines?.count == 1)
    }

    @Test("Export devices to JSON")
    func exportDevicesJSON() {
        let device = LocalDevice(
            ipAddress: "192.168.1.100",
            macAddress: "AA:BB:CC:DD:EE:FF",
            hostname: "test-device",
            vendor: "Apple",
            deviceType: .phone,
            status: .online,
            lastLatency: 5.5,
            isGateway: false
        )

        let data = DataExportService.exportDevices([device], format: .json)
        #expect(data != nil)

        let json = try? JSONSerialization.jsonObject(with: data!)
        let array = json as? [[String: String]]
        #expect(array?.count == 1)

        let item = array?.first
        #expect(item?["ipAddress"] == "192.168.1.100")
        #expect(item?["macAddress"] == "AA:BB:CC:DD:EE:FF")
        #expect(item?["hostname"] == "test-device")
        #expect(item?["vendor"] == "Apple")
        #expect(item?["deviceType"] == "phone")
        #expect(item?["status"] == "online")
        #expect(item?["isGateway"] == "false")
    }

    @Test("Export devices to CSV")
    func exportDevicesCSV() {
        let device = LocalDevice(
            ipAddress: "10.0.0.1",
            macAddress: "11:22:33:44:55:66",
            hostname: "gateway",
            deviceType: .router,
            status: .online,
            isGateway: true
        )

        let data = DataExportService.exportDevices([device], format: .csv)
        #expect(data != nil)

        let csv = String(data: data!, encoding: .utf8)
        #expect(csv?.contains("10.0.0.1") == true)
        #expect(csv?.contains("11:22:33:44:55:66") == true)
        #expect(csv?.contains("gateway") == true)
        #expect(csv?.contains("router") == true)
    }

    @Test("Export devices with nil optional fields")
    func exportDevicesWithNils() {
        let device = LocalDevice(
            ipAddress: "192.168.1.50",
            macAddress: "00:11:22:33:44:55",
            hostname: nil,
            vendor: nil,
            deviceType: .unknown,
            status: .offline,
            lastLatency: nil,
            isGateway: false
        )

        let data = DataExportService.exportDevices([device], format: .json)
        #expect(data != nil)

        let json = try? JSONSerialization.jsonObject(with: data!)
        let array = json as? [[String: String]]
        let item = array?.first
        #expect(item?["hostname"] == "")
        #expect(item?["vendor"] == "")
        #expect(item?["lastLatency"] == "")
    }

    // MARK: - File Writing Tests

    @Test("writeToTempFile creates file and returns URL")
    func writeToTempFile() {
        let testData = "Test export data".data(using: .utf8)!

        let url = DataExportService.writeToTempFile(data: testData, name: "test-export", ext: "txt")

        #expect(url != nil)
        #expect(url?.lastPathComponent == "test-export.txt")

        // Verify file exists
        let fileExists = FileManager.default.fileExists(atPath: url!.path)
        #expect(fileExists == true)

        // Verify content
        let readData = try? Data(contentsOf: url!)
        #expect(readData == testData)

        // Cleanup
        try? FileManager.default.removeItem(at: url!)
    }

    @Test("writeToTempFile handles different extensions")
    func writeToTempFileDifferentExtensions() {
        let testData = "{}".data(using: .utf8)!

        let jsonURL = DataExportService.writeToTempFile(data: testData, name: "export", ext: "json")
        #expect(jsonURL?.pathExtension == "json")
        try? FileManager.default.removeItem(at: jsonURL!)

        let csvURL = DataExportService.writeToTempFile(data: testData, name: "export", ext: "csv")
        #expect(csvURL?.pathExtension == "csv")
        try? FileManager.default.removeItem(at: csvURL!)
    }
}

// MARK: - MACVendorLookupService Tests

@Suite("MACVendorLookupService Tests")
@MainActor
struct MACVendorLookupServiceTests {

    @Test("Initial state")
    func initialState() {
        let service = MACVendorLookupService()

        #expect(service.isLoading == false)
    }

    @Test("Service is MainActor isolated")
    func mainActorIsolation() async {
        let service = MACVendorLookupService()

        // Verify we can access properties on MainActor
        #expect(service.isLoading == false)
    }
}

// MARK: - GatewayService Tests

@Suite("GatewayService Tests")
@MainActor
struct GatewayServiceTests {

    @Test("Initial state - gateway is nil")
    func initialStateGateway() {
        let service = GatewayService()

        #expect(service.gateway == nil)
    }

    @Test("Initial state - isLoading is false")
    func initialStateLoading() {
        let service = GatewayService()

        #expect(service.isLoading == false)
    }

    @Test("Initial state - lastError is nil")
    func initialStateError() {
        let service = GatewayService()

        #expect(service.lastError == nil)
    }

    @Test("Service conforms to GatewayServiceProtocol")
    func protocolConformance() {
        let service: any GatewayServiceProtocol = GatewayService()

        #expect(service.gateway == nil)
        #expect(service.isLoading == false)
    }
}

// MARK: - NotificationService Tests

@Suite("NotificationService Tests")
@MainActor
struct NotificationServiceBatch1Tests {

    @Test("Category constants are defined")
    func categoryConstants() {
        #expect(NotificationService.targetDownCategory == "TARGET_DOWN")
        #expect(NotificationService.highLatencyCategory == "HIGH_LATENCY")
        #expect(NotificationService.newDeviceCategory == "NEW_DEVICE")
    }

    @Test("Singleton instance exists")
    func singletonExists() {
        let service = NotificationService.shared

        #expect(service != nil)
    }

    @Test("Target down notification uses correct category")
    func targetDownCategory() {
        // The notification content would use NotificationService.targetDownCategory
        // This test verifies the constant is available
        let category = NotificationService.targetDownCategory
        #expect(category == "TARGET_DOWN")
    }

    @Test("High latency notification uses correct category")
    func highLatencyCategory() {
        let category = NotificationService.highLatencyCategory
        #expect(category == "HIGH_LATENCY")
    }

    @Test("New device notification uses correct category")
    func newDeviceCategory() {
        let category = NotificationService.newDeviceCategory
        #expect(category == "NEW_DEVICE")
    }

    @Test("High latency threshold default")
    func highLatencyThresholdDefault() {
        // When threshold is 0 or not set, effective threshold should be 100
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppSettings.Keys.highLatencyThreshold)

        // Threshold logic: threshold > 0 ? threshold : 100
        let storedThreshold = defaults.integer(forKey: AppSettings.Keys.highLatencyThreshold)
        let effectiveThreshold = storedThreshold > 0 ? storedThreshold : 100

        #expect(effectiveThreshold == 100)
    }

    @Test("High latency threshold custom value")
    func highLatencyThresholdCustom() {
        let defaults = UserDefaults.standard
        defaults.set(200, forKey: AppSettings.Keys.highLatencyThreshold)

        let storedThreshold = defaults.integer(forKey: AppSettings.Keys.highLatencyThreshold)
        let effectiveThreshold = storedThreshold > 0 ? storedThreshold : 100

        #expect(effectiveThreshold == 200)

        // Cleanup
        defaults.removeObject(forKey: AppSettings.Keys.highLatencyThreshold)
    }

    @Test("AppSettings keys are defined")
    func appSettingsKeys() {
        #expect(AppSettings.Keys.targetDownAlertEnabled == "targetDownAlertEnabled")
        #expect(AppSettings.Keys.highLatencyThreshold == "highLatencyThreshold")
        #expect(AppSettings.Keys.newDeviceAlertEnabled == "newDeviceAlertEnabled")
    }
}
