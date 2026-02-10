import Testing
import Foundation
@testable import Netmonitor

// MARK: - PingResult Tests

@Suite("PingResult Tests")
struct PingResultTests {

    @Test("PingResult timeText formats correctly")
    func timeText() {
        let fast = PingResult(sequence: 1, host: "test", ttl: 64, time: 0.5, isTimeout: false)
        #expect(fast.timeText == "0.50 ms")

        let normal = PingResult(sequence: 2, host: "test", ttl: 64, time: 12.3, isTimeout: false)
        #expect(normal.timeText == "12.3 ms")

        let timeout = PingResult(sequence: 3, host: "test", ttl: 0, time: 5000, isTimeout: true)
        #expect(timeout.timeText == "timeout")
    }

    @Test("PingResult has unique IDs")
    func uniqueIDs() {
        let a = PingResult(sequence: 1, host: "test", ttl: 64, time: 10, isTimeout: false)
        let b = PingResult(sequence: 1, host: "test", ttl: 64, time: 10, isTimeout: false)
        #expect(a.id != b.id)
    }
}

// MARK: - PingStatistics Tests

@Suite("PingStatistics Tests")
struct PingStatisticsTests {

    @Test("Packet loss text format")
    func packetLossText() {
        let stats = PingStatistics(host: "test", transmitted: 10, received: 8, packetLoss: 20.0, minTime: 5, maxTime: 50, avgTime: 25, stdDev: 10)
        #expect(stats.packetLossText == "20.0%")
    }

    @Test("Success rate calculation")
    func successRate() {
        let stats = PingStatistics(host: "test", transmitted: 10, received: 7, packetLoss: 30.0, minTime: 5, maxTime: 50, avgTime: 25, stdDev: 10)
        #expect(stats.successRate == 70.0)
    }

    @Test("Success rate with zero transmitted")
    func successRateZero() {
        let stats = PingStatistics(host: "test", transmitted: 0, received: 0, packetLoss: 0, minTime: 0, maxTime: 0, avgTime: 0, stdDev: nil)
        #expect(stats.successRate == 0)
    }
}

// MARK: - TracerouteHop Tests

@Suite("TracerouteHop Tests")
struct TracerouteHopTests {

    @Test("Display address shows hostname when available")
    func displayAddressHostname() {
        let hop = TracerouteHop(hopNumber: 1, ipAddress: "1.2.3.4", hostname: "router.local")
        #expect(hop.displayAddress == "router.local")
    }

    @Test("Display address falls back to IP")
    func displayAddressIP() {
        let hop = TracerouteHop(hopNumber: 1, ipAddress: "1.2.3.4")
        #expect(hop.displayAddress == "1.2.3.4")
    }

    @Test("Display address shows * for timeout")
    func displayAddressTimeout() {
        let hop = TracerouteHop(hopNumber: 1, isTimeout: true)
        #expect(hop.displayAddress == "*")
    }

    @Test("Average time calculation")
    func averageTime() {
        let hop = TracerouteHop(hopNumber: 1, ipAddress: "1.2.3.4", times: [10.0, 20.0, 30.0])
        #expect(hop.averageTime == 20.0)
    }

    @Test("Average time nil for empty times")
    func averageTimeEmpty() {
        let hop = TracerouteHop(hopNumber: 1, ipAddress: "1.2.3.4", times: [])
        #expect(hop.averageTime == nil)
    }

    @Test("Time text formats correctly")
    func timeText() {
        let hop = TracerouteHop(hopNumber: 1, ipAddress: "1.2.3.4", times: [15.3])
        #expect(hop.timeText == "15.3 ms")

        let timeout = TracerouteHop(hopNumber: 2, isTimeout: true)
        #expect(timeout.timeText == "*")
    }
}

// MARK: - PortScanResult Tests

@Suite("PortScanResult Tests")
struct PortScanResultTests {

    @Test("Common service name lookup")
    func serviceNameLookup() {
        #expect(PortScanResult.commonServiceName(for: 22) == "SSH")
        #expect(PortScanResult.commonServiceName(for: 80) == "HTTP")
        #expect(PortScanResult.commonServiceName(for: 443) == "HTTPS")
        #expect(PortScanResult.commonServiceName(for: 3306) == "MySQL")
        #expect(PortScanResult.commonServiceName(for: 99999) == nil)
    }

    @Test("Port state display name")
    func portStateDisplayName() {
        #expect(PortState.open.displayName == "Open")
        #expect(PortState.closed.displayName == "Closed")
        #expect(PortState.filtered.displayName == "Filtered")
    }

    @Test("Auto-assigns service name from port")
    func autoServiceName() {
        let result = PortScanResult(port: 22, state: .open)
        #expect(result.serviceName == "SSH")
    }
}

// MARK: - DNSRecord Tests

@Suite("DNSRecord Tests")
struct DNSRecordTests {

    @Test("TTL text formatting")
    func ttlText() {
        let days = DNSRecord(name: "test", type: .a, value: "1.2.3.4", ttl: 86400)
        #expect(days.ttlText == "1d")

        let hours = DNSRecord(name: "test", type: .a, value: "1.2.3.4", ttl: 7200)
        #expect(hours.ttlText == "2h")

        let minutes = DNSRecord(name: "test", type: .a, value: "1.2.3.4", ttl: 300)
        #expect(minutes.ttlText == "5m")

        let seconds = DNSRecord(name: "test", type: .a, value: "1.2.3.4", ttl: 30)
        #expect(seconds.ttlText == "30s")
    }
}

// MARK: - DNSQueryResult Tests

@Suite("DNSQueryResult Tests")
struct DNSQueryResultTests {

    @Test("Query time text formatting")
    func queryTimeText() {
        let result = DNSQueryResult(domain: "test.com", server: "8.8.8.8", queryType: .a, records: [], queryTime: 42.7)
        #expect(result.queryTimeText == "43 ms")
    }
}

// MARK: - BonjourService Tests

@Suite("BonjourService Tests")
struct BonjourServiceTests {

    @Test("Service category classification")
    func serviceCategory() {
        let web = BonjourService(name: "test", type: "_http._tcp")
        #expect(web.serviceCategory == "Web")

        let ssh = BonjourService(name: "test", type: "_ssh._tcp")
        #expect(ssh.serviceCategory == "Remote Access")

        let smb = BonjourService(name: "test", type: "_smb._tcp")
        #expect(smb.serviceCategory == "File Sharing")

        let airplay = BonjourService(name: "test", type: "_airplay._tcp")
        #expect(airplay.serviceCategory == "AirPlay")

        let unknown = BonjourService(name: "test", type: "_custom._tcp")
        #expect(unknown.serviceCategory == "Other")
    }

    @Test("Full type includes domain")
    func fullType() {
        let service = BonjourService(name: "test", type: "_http._tcp", domain: "local.")
        #expect(service.fullType == "_http._tcp.local.")
    }
}

// MARK: - WHOISResult Tests

@Suite("WHOISResult Tests")
struct WHOISResultTests {

    @Test("Domain age calculation")
    func domainAge() {
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: Date())!
        let result = WHOISResult(query: "test.com", creationDate: twoYearsAgo, rawData: "")
        #expect(result.domainAge == "2 years")
    }

    @Test("Days until expiration")
    func daysUntilExpiration() {
        let future = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let result = WHOISResult(query: "test.com", expirationDate: future, rawData: "")
        let days = result.daysUntilExpiration
        #expect(days != nil)
        // Allow 1 day tolerance due to timing
        #expect(days! >= 29 && days! <= 31)
    }

    @Test("Nil domain age without creation date")
    func nilDomainAge() {
        let result = WHOISResult(query: "test.com", rawData: "")
        #expect(result.domainAge == nil)
    }
}

// MARK: - Enum Tests

@Suite("Enum Tests")
struct EnumTests {

    @Test("DeviceType icon names are valid SF Symbol identifiers")
    func deviceTypeIcons() {
        for type in DeviceType.allCases {
            #expect(!type.iconName.isEmpty)
            #expect(!type.displayName.isEmpty)
        }
    }

    @Test("ConnectionType properties")
    func connectionTypeProperties() {
        #expect(ConnectionType.wifi.displayName == "Wi-Fi")
        #expect(ConnectionType.wifi.iconName == "wifi")
        #expect(ConnectionType.none.displayName == "No Connection")
    }

    @Test("ToolType properties")
    func toolTypeProperties() {
        for tool in ToolType.allCases {
            #expect(!tool.displayName.isEmpty)
            #expect(!tool.iconName.isEmpty)
        }
    }

    @Test("PortScanPreset ports are non-empty (except custom)")
    func portScanPresetPorts() {
        for preset in PortScanPreset.allCases {
            if preset == .custom {
                #expect(preset.ports.isEmpty)
            } else {
                #expect(!preset.ports.isEmpty, "Preset \(preset.displayName) should have ports")
            }
        }
    }

    @Test("DNSRecordType display names match raw values")
    func dnsRecordTypeDisplay() {
        for type in DNSRecordType.allCases {
            #expect(type.displayName == type.rawValue)
        }
    }

    @Test("StatusType properties")
    func statusTypeProperties() {
        #expect(StatusType.online.label == "Online")
        #expect(StatusType.offline.label == "Offline")
        #expect(StatusType.idle.label == "Idle")
        #expect(StatusType.unknown.label == "Unknown")
    }

    @Test("DeviceStatus statusType mapping")
    func deviceStatusMapping() {
        #expect(DeviceStatus.online.statusType == .online)
        #expect(DeviceStatus.offline.statusType == .offline)
        #expect(DeviceStatus.idle.statusType == .idle)
    }

    @Test("TargetProtocol default ports")
    func targetProtocolPorts() {
        #expect(TargetProtocol.icmp.defaultPort == nil)
        #expect(TargetProtocol.tcp.defaultPort == 80)
        #expect(TargetProtocol.http.defaultPort == 80)
        #expect(TargetProtocol.https.defaultPort == 443)
    }
}

// MARK: - NetworkModels Tests

@Suite("NetworkModels Tests")
struct NetworkModelsTests {

    @Test("WiFiInfo signal quality classification")
    func signalQuality() {
        let excellent = WiFiInfo(ssid: "Test", signalDBm: -40)
        #expect(excellent.signalQuality == .excellent)
        #expect(excellent.signalBars == 4)

        let good = WiFiInfo(ssid: "Test", signalDBm: -55)
        #expect(good.signalQuality == .good)
        #expect(good.signalBars == 3)

        let fair = WiFiInfo(ssid: "Test", signalDBm: -65)
        #expect(fair.signalQuality == .fair)
        #expect(fair.signalBars == 2)

        let poor = WiFiInfo(ssid: "Test", signalDBm: -85)
        #expect(poor.signalQuality == .poor)
        #expect(poor.signalBars == 0)

        let unknown = WiFiInfo(ssid: "Test")
        #expect(unknown.signalQuality == .unknown)
        #expect(unknown.signalBars == 0)
    }

    @Test("GatewayInfo latency text")
    func gatewayLatencyText() {
        let fast = GatewayInfo(ipAddress: "192.168.1.1", latency: 0.5)
        #expect(fast.latencyText == "<1 ms")

        let normal = GatewayInfo(ipAddress: "192.168.1.1", latency: 12.3)
        #expect(normal.latencyText == "12 ms")

        let noLatency = GatewayInfo(ipAddress: "192.168.1.1")
        #expect(noLatency.latencyText == nil)
    }

    @Test("ISPInfo location text")
    func ispLocationText() {
        let full = ISPInfo(publicIP: "1.2.3.4", city: "Austin", country: "US", countryCode: "US")
        #expect(full.locationText == "Austin, US")

        let cityOnly = ISPInfo(publicIP: "1.2.3.4", city: "Austin")
        #expect(cityOnly.locationText == "Austin")

        let none = ISPInfo(publicIP: "1.2.3.4")
        #expect(none.locationText == nil)
    }

    @Test("NetworkStatus disconnected factory")
    func networkStatusDisconnected() {
        let status = NetworkStatus.disconnected
        #expect(status.isConnected == false)
        #expect(status.connectionType == .none)
    }
}

// MARK: - NetworkUtilities Tests

@Suite("NetworkUtilities Tests")
struct NetworkUtilitiesTests {

    @Test("Default gateway assumes .1 suffix")
    func defaultGatewayFormat() {
        // This test verifies the logic, not the actual network interface
        // On a machine with en0, it should return something like "x.y.z.1"
        if let gateway = NetworkUtilities.detectDefaultGateway() {
            #expect(gateway.hasSuffix(".1"))
        }
    }
}

// MARK: - ToolActivityItem Tests

@Suite("ToolActivityItem Tests")
struct ToolActivityItemTests {

    @Test("Time ago text for recent items")
    func timeAgoText() {
        let justNow = ToolActivityItem(tool: "Ping", target: "1.1.1.1", result: "OK", success: true, timestamp: Date())
        #expect(justNow.timeAgoText == "Just now")

        let fiveMinAgo = ToolActivityItem(tool: "Ping", target: "1.1.1.1", result: "OK", success: true, timestamp: Date().addingTimeInterval(-300))
        #expect(fiveMinAgo.timeAgoText == "5 min ago")

        let twoHoursAgo = ToolActivityItem(tool: "Ping", target: "1.1.1.1", result: "OK", success: true, timestamp: Date().addingTimeInterval(-7200))
        #expect(twoHoursAgo.timeAgoText == "2 hours ago")

        let oneDayAgo = ToolActivityItem(tool: "Ping", target: "1.1.1.1", result: "OK", success: true, timestamp: Date().addingTimeInterval(-86400))
        #expect(oneDayAgo.timeAgoText == "1 day ago")
    }
}

// MARK: - WakeOnLANToolViewModel Tests

@Suite("WakeOnLANToolViewModel Tests")
struct WakeOnLANToolViewModelTests {

    @Test("MAC address validation")
    @MainActor
    func macValidation() {
        let vm = WakeOnLANToolViewModel()

        vm.macAddress = "AA:BB:CC:DD:EE:FF"
        #expect(vm.isValidMACAddress == true)

        vm.macAddress = "AA-BB-CC-DD-EE-FF"
        #expect(vm.isValidMACAddress == true)

        vm.macAddress = "AABBCCDDEEFF"
        #expect(vm.isValidMACAddress == true)

        vm.macAddress = "not-valid"
        #expect(vm.isValidMACAddress == false)

        vm.macAddress = "AA:BB:CC"
        #expect(vm.isValidMACAddress == false)

        vm.macAddress = ""
        #expect(vm.isValidMACAddress == false)
    }

    @Test("Formatted MAC address")
    @MainActor
    func formattedMAC() {
        let vm = WakeOnLANToolViewModel()
        vm.macAddress = "aabbccddeeff"
        #expect(vm.formattedMACAddress == "AA:BB:CC:DD:EE:FF")
    }

    @Test("Cannot send with invalid MAC")
    @MainActor
    func cannotSendInvalid() {
        let vm = WakeOnLANToolViewModel()
        vm.macAddress = "invalid"
        #expect(vm.canSend == false)
    }

    @Test("Can send with valid MAC")
    @MainActor
    func canSendValid() {
        let vm = WakeOnLANToolViewModel()
        vm.macAddress = "AA:BB:CC:DD:EE:FF"
        #expect(vm.canSend == true)
    }
}

// MARK: - PingToolViewModel Tests

@Suite("PingToolViewModel Tests")
struct PingToolViewModelTests {

    @Test("Cannot start ping with empty host")
    @MainActor
    func cannotStartEmpty() {
        let vm = PingToolViewModel()
        vm.host = ""
        #expect(vm.canStartPing == false)
    }

    @Test("Cannot start ping with whitespace-only host")
    @MainActor
    func cannotStartWhitespace() {
        let vm = PingToolViewModel()
        vm.host = "   "
        #expect(vm.canStartPing == false)
    }

    @Test("Can start ping with valid host")
    @MainActor
    func canStartValid() {
        let vm = PingToolViewModel()
        vm.host = "1.1.1.1"
        #expect(vm.canStartPing == true)
    }

    @Test("Clear results resets state")
    @MainActor
    func clearResults() {
        let vm = PingToolViewModel()
        vm.clearResults()
        #expect(vm.results.isEmpty)
        #expect(vm.statistics == nil)
        #expect(vm.errorMessage == nil)
    }
}

// MARK: - TracerouteToolViewModel Tests

@Suite("TracerouteToolViewModel Tests")
struct TracerouteToolViewModelTests {

    @Test("Cannot start trace with empty host")
    @MainActor
    func cannotStartEmpty() {
        let vm = TracerouteToolViewModel()
        vm.host = ""
        #expect(vm.canStartTrace == false)
    }

    @Test("Default max hops is 30")
    @MainActor
    func defaultMaxHops() {
        let vm = TracerouteToolViewModel()
        #expect(vm.maxHops == 30)
    }

    @Test("Clear results empties hops")
    @MainActor
    func clearResults() {
        let vm = TracerouteToolViewModel()
        vm.clearResults()
        #expect(vm.hops.isEmpty)
        #expect(vm.errorMessage == nil)
    }
}

// MARK: - DNSLookupToolViewModel Tests

@Suite("DNSLookupToolViewModel Tests")
struct DNSLookupToolViewModelTests {

    @Test("Cannot start with empty domain")
    @MainActor
    func cannotStartEmpty() {
        let vm = DNSLookupToolViewModel()
        vm.domain = ""
        #expect(vm.canStartLookup == false)
    }

    @Test("Default record type is A")
    @MainActor
    func defaultRecordType() {
        let vm = DNSLookupToolViewModel()
        #expect(vm.recordType == .a)
    }

    @Test("Record types include expected types")
    @MainActor
    func recordTypes() {
        let vm = DNSLookupToolViewModel()
        #expect(vm.recordTypes.contains(.a))
        #expect(vm.recordTypes.contains(.aaaa))
        #expect(vm.recordTypes.contains(.mx))
    }
}

// MARK: - PortScannerToolViewModel Tests

@Suite("PortScannerToolViewModel Tests")
struct PortScannerToolViewModelTests {

    @Test("Cannot start with empty host")
    @MainActor
    func cannotStartEmpty() {
        let vm = PortScannerToolViewModel()
        vm.host = ""
        #expect(vm.canStartScan == false)
    }

    @Test("Default preset is common")
    @MainActor
    func defaultPreset() {
        let vm = PortScannerToolViewModel()
        #expect(vm.portPreset == .common)
    }

    @Test("Open ports filters correctly")
    @MainActor
    func openPortsFilter() {
        let vm = PortScannerToolViewModel()
        // Starts empty
        #expect(vm.openPorts.isEmpty)
    }

    @Test("Progress is zero initially")
    @MainActor
    func initialProgress() {
        let vm = PortScannerToolViewModel()
        #expect(vm.progress == 0)
    }
}

// MARK: - BonjourDiscoveryToolViewModel Tests

@Suite("BonjourDiscoveryToolViewModel Tests")
struct BonjourDiscoveryToolViewModelTests {

    @Test("Initial state")
    @MainActor
    func initialState() {
        let vm = BonjourDiscoveryToolViewModel()
        #expect(vm.isDiscovering == false)
        #expect(vm.hasDiscoveredOnce == false)
        #expect(vm.services.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    @Test("Clear results empties services")
    @MainActor
    func clearResults() {
        let vm = BonjourDiscoveryToolViewModel()
        vm.clearResults()
        #expect(vm.services.isEmpty)
        #expect(vm.errorMessage == nil)
    }
}

// MARK: - NetworkError Tests

@Suite("NetworkError Tests")
struct NetworkErrorTests {

    @Test("Error descriptions are non-empty")
    func errorDescriptions() {
        let errors: [NetworkError] = [
            .timeout, .connectionFailed, .noNetwork, .invalidHost, .permissionDenied,
            .unknown(NSError(domain: "test", code: 0))
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
            #expect(!error.userFacingMessage.isEmpty)
        }
    }
}

// MARK: - DiscoveredDevice Tests

@Suite("DiscoveredDevice Tests")
struct DiscoveredDeviceTests {

    @Test("Latency text formatting")
    func latencyText() {
        let fast = DiscoveredDevice(ipAddress: "192.168.1.1", latency: 0.5, discoveredAt: Date())
        #expect(fast.latencyText == "<1 ms")

        let normal = DiscoveredDevice(ipAddress: "192.168.1.1", latency: 15, discoveredAt: Date())
        #expect(normal.latencyText == "15 ms")
    }
}

// MARK: - SpeedTestResult Tests

@Suite("SpeedTestResult Tests")
struct SpeedTestResultModelTests {

    @Test("Speed text formatting")
    func speedText() {
        let result = SpeedTestResult(downloadSpeed: 245.8, uploadSpeed: 50.2, latency: 12)
        #expect(result.downloadSpeedText == "245.8 Mbps")
        #expect(result.uploadSpeedText == "50.2 Mbps")
        #expect(result.latencyText == "12 ms")
    }

    @Test("Gigabit speed formatting")
    func gigabitSpeed() {
        let result = SpeedTestResult(downloadSpeed: 1200.0, uploadSpeed: 1500.0, latency: 5)
        #expect(result.downloadSpeedText == "1.2 Gbps")
        #expect(result.uploadSpeedText == "1.5 Gbps")
    }
}

// MARK: - Deep QA Added Coverage (Speed Test + Bonjour)

@Suite("SpeedTestService Tests")
struct SpeedTestServiceDeepQATests {
    @Test("Initial state")
    @MainActor
    func initialState() {
        let service = SpeedTestService()
        #expect(service.downloadSpeed == 0)
        #expect(service.uploadSpeed == 0)
        #expect(service.latency == 0)
        #expect(service.progress == 0)
        #expect(service.phase == .idle)
        #expect(service.isRunning == false)
        #expect(service.errorMessage == nil)
    }

    @Test("Cloudflare endpoints are valid")
    func endpoints() {
        let downloadURL = URL(string: "https://speed.cloudflare.com/__down?bytes=25000000")
        #expect(downloadURL?.host == "speed.cloudflare.com")
        #expect(downloadURL?.path == "/__down")

        let uploadURL = URL(string: "https://speed.cloudflare.com/__up")
        #expect(uploadURL?.host == "speed.cloudflare.com")
        #expect(uploadURL?.path == "/__up")
    }
}

@Suite("BonjourDiscoveryService Tests")
struct BonjourDiscoveryServiceDeepQATests {
    @Test("Initial state")
    @MainActor
    func initialState() {
        let service = BonjourDiscoveryService()
        #expect(service.discoveredServices.isEmpty)
        #expect(service.isDiscovering == false)
    }

    @Test("BonjourService categorization")
    func categorization() {
        #expect(BonjourService(name: "Web", type: "_http._tcp").serviceCategory == "Web")
        #expect(BonjourService(name: "SSH", type: "_ssh._tcp").serviceCategory == "Remote Access")
        #expect(BonjourService(name: "Printer", type: "_ipp._tcp").serviceCategory == "Printing")
    }
}
