import Testing
import Foundation
import Network
@testable import Netmonitor

// NOTE: MacConnectionState and DiscoveredMac type-level tests are in ServiceTestsBatch3.swift.
// This file covers MacConnectionService instance behaviour: initial state, browsing, disconnect, send.

// MARK: - MacConnectionService Initial State Tests

@Suite("MacConnectionService Initial State Tests")
@MainActor
struct MacConnectionServiceInitialStateTests {

    @Test("initial connectionState is disconnected")
    func initialConnectionState() {
        let service = MacConnectionService()
        #expect(service.connectionState == .disconnected)
    }

    @Test("initial discoveredMacs is empty")
    func initialDiscoveredMacs() {
        let service = MacConnectionService()
        #expect(service.discoveredMacs.isEmpty)
    }

    @Test("initial isBrowsing is false")
    func initialIsBrowsing() {
        let service = MacConnectionService()
        #expect(service.isBrowsing == false)
    }

    @Test("connectedMacName is nil when disconnected")
    func connectedMacNameNilWhenDisconnected() {
        let service = MacConnectionService()
        #expect(service.connectedMacName == nil)
    }

    @Test("initial lastStatusUpdate is nil")
    func initialLastStatusUpdate() {
        let service = MacConnectionService()
        #expect(service.lastStatusUpdate == nil)
    }

    @Test("initial lastTargetList is nil")
    func initialLastTargetList() {
        let service = MacConnectionService()
        #expect(service.lastTargetList == nil)
    }

    @Test("initial lastDeviceList is nil")
    func initialLastDeviceList() {
        let service = MacConnectionService()
        #expect(service.lastDeviceList == nil)
    }
}

// MARK: - MacConnectionService Browsing Tests

@Suite("MacConnectionService Browsing Tests")
@MainActor
struct MacConnectionServiceBrowsingTests {

    @Test("startBrowsing sets isBrowsing to true")
    func startBrowsingSetsIsBrowsing() {
        let service = MacConnectionService()
        service.startBrowsing()
        #expect(service.isBrowsing == true)
        service.stopBrowsing()
    }

    @Test("startBrowsing clears discoveredMacs")
    func startBrowsingClearsDiscoveredMacs() {
        let service = MacConnectionService()
        service.startBrowsing()
        #expect(service.discoveredMacs.isEmpty)
        service.stopBrowsing()
    }

    @Test("stopBrowsing sets isBrowsing to false")
    func stopBrowsingSetsIsBrowsingFalse() {
        let service = MacConnectionService()
        service.startBrowsing()
        service.stopBrowsing()
        #expect(service.isBrowsing == false)
    }

    @Test("stopBrowsing without prior startBrowsing does not crash")
    func stopBrowsingWithoutStarting() {
        let service = MacConnectionService()
        service.stopBrowsing()
        #expect(service.isBrowsing == false)
    }

    @Test("calling startBrowsing twice leaves isBrowsing true")
    func startBrowsingTwice() {
        let service = MacConnectionService()
        service.startBrowsing()
        service.startBrowsing()
        #expect(service.isBrowsing == true)
        service.stopBrowsing()
    }
}

// MARK: - MacConnectionService Disconnect Tests

@Suite("MacConnectionService Disconnect Tests")
@MainActor
struct MacConnectionServiceDisconnectTests {

    @Test("disconnect resets connectionState to disconnected")
    func disconnectResetsConnectionState() {
        let service = MacConnectionService()
        service.disconnect()
        #expect(service.connectionState == .disconnected)
    }

    @Test("disconnect clears connectedMacName")
    func disconnectClearsConnectedMacName() {
        let service = MacConnectionService()
        service.disconnect()
        #expect(service.connectedMacName == nil)
    }

    @Test("disconnect clears lastStatusUpdate")
    func disconnectClearsLastStatusUpdate() {
        let service = MacConnectionService()
        service.disconnect()
        #expect(service.lastStatusUpdate == nil)
    }

    @Test("disconnect clears lastTargetList")
    func disconnectClearsLastTargetList() {
        let service = MacConnectionService()
        service.disconnect()
        #expect(service.lastTargetList == nil)
    }

    @Test("disconnect clears lastDeviceList")
    func disconnectClearsLastDeviceList() {
        let service = MacConnectionService()
        service.disconnect()
        #expect(service.lastDeviceList == nil)
    }

    @Test("calling disconnect multiple times does not crash")
    func multipleDisconnectCalls() {
        let service = MacConnectionService()
        service.disconnect()
        service.disconnect()
        service.disconnect()
        #expect(service.connectionState == .disconnected)
    }
}

// MARK: - MacConnectionService Send When Disconnected Tests

@Suite("MacConnectionService Send When Disconnected Tests")
@MainActor
struct MacConnectionServiceSendTests {

    @Test("send command when disconnected handles gracefully without crash")
    func sendCommandWhenDisconnected() async {
        let service = MacConnectionService()
        let command = CommandPayload(action: .startMonitoring)
        await service.send(command: command)
        #expect(service.connectionState == .disconnected)
    }

    @Test("send ping command with parameters when disconnected is a no-op")
    func sendPingCommandWithParametersWhenDisconnected() async {
        let service = MacConnectionService()
        let command = CommandPayload(action: .ping, parameters: ["host": "8.8.8.8", "count": "4"])
        await service.send(command: command)
        #expect(service.connectionState == .disconnected)
    }

    @Test("send all ten command actions when disconnected does not crash")
    func sendAllActionsWhenDisconnected() async {
        let service = MacConnectionService()
        let actions: [CommandAction] = [
            .startMonitoring, .stopMonitoring, .scanDevices,
            .ping, .traceroute, .portScan, .dnsLookup,
            .wakeOnLan, .refreshTargets, .refreshDevices
        ]
        for action in actions {
            await service.send(command: CommandPayload(action: action))
        }
        #expect(service.connectionState == .disconnected)
    }
}
