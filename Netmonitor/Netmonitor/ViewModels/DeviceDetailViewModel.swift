import Foundation
import SwiftData

@MainActor
@Observable
final class DeviceDetailViewModel {
    var device: LocalDevice?
    var isLoading: Bool = false
    var error: String?
    var isScanning: Bool = false
    var isDiscovering: Bool = false

    private let macLookupService = MACVendorLookupService()
    private let nameResolver = DeviceNameResolver()
    private let portScanner = PortScannerService()
    private let bonjourService = BonjourDiscoveryService()

    // Common ports to scan
    private let commonPorts = [
        21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 548, 631,
        993, 995, 3306, 3389, 5432, 5900, 8080, 8443
    ]

    /// Load device from SwiftData by IP address, creating one if not found
    func loadDevice(ipAddress: String, context: ModelContext) {
        let descriptor = FetchDescriptor<LocalDevice>(
            predicate: #Predicate { $0.ipAddress == ipAddress }
        )
        if let existing = try? context.fetch(descriptor).first {
            device = existing
        } else {
            let newDevice = LocalDevice(
                ipAddress: ipAddress,
                macAddress: ""
            )
            context.insert(newDevice)
            device = newDevice
        }
    }

    /// Enrich device data with manufacturer and resolved hostname
    func enrichDevice(bonjourServices: [BonjourService]) async {
        guard let device = device else { return }
        isLoading = true
        defer { isLoading = false }

        // Extract Sendable values before async work
        let macAddress = device.macAddress
        let ipAddress = device.ipAddress

        // Lookup manufacturer from MAC address (skip if empty)
        if device.manufacturer == nil, !macAddress.isEmpty {
            let lookupTask = Task { await self.macLookupService.lookup(macAddress: macAddress) }
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(5))
                lookupTask.cancel()
            }
            let manufacturer = await lookupTask.value
            timeoutTask.cancel()
            if !Task.isCancelled { device.manufacturer = manufacturer }
        }

        guard !Task.isCancelled else { return }

        // Resolve hostname with timeout to prevent hanging on DNS
        if device.resolvedHostname == nil {
            let resolveTask = Task {
                await self.nameResolver.resolve(ipAddress: ipAddress, bonjourServices: bonjourServices)
            }
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(8))
                resolveTask.cancel()
            }
            let hostname = await resolveTask.value
            timeoutTask.cancel()
            if !Task.isCancelled { device.resolvedHostname = hostname }
        }
    }

    /// Scan common ports on the device
    func scanPorts() async {
        guard let device = device else { return }
        isScanning = true
        defer { isScanning = false }

        var openPorts: [Int] = []

        for await result in await portScanner.scan(host: device.ipAddress, ports: commonPorts, timeout: 1.5) {
            if result.state == .open {
                openPorts.append(result.port)
            }
        }

        device.openPorts = openPorts.sorted()
    }

    /// Discover Bonjour services matching this device's IP
    func discoverServices() async {
        guard let device = device else { return }
        isDiscovering = true
        defer { isDiscovering = false }

        var discoveredServiceNames: [String] = []

        // Start discovery and collect services for 10 seconds
        let stream = bonjourService.discoveryStream()

        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(10))
            bonjourService.stopDiscovery()
        }

        for await service in stream {
            // Resolve the service to get its IP address
            if let resolved = await bonjourService.resolveService(service),
               let hostName = resolved.hostName,
               hostName.contains(device.ipAddress) || device.ipAddress.hasPrefix(hostName.components(separatedBy: ".").prefix(3).joined(separator: ".")) {
                let serviceName = "\(service.name) (\(service.type))"
                if !discoveredServiceNames.contains(serviceName) {
                    discoveredServiceNames.append(serviceName)
                }
            }
        }

        timeoutTask.cancel()
        device.discoveredServices = discoveredServiceNames
    }
}
