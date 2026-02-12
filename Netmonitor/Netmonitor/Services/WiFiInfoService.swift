import Foundation
import SystemConfiguration.CaptiveNetwork
import CoreLocation
import Network

@MainActor
@Observable
final class WiFiInfoService: NSObject {
    private(set) var currentWiFi: WiFiInfo?
    private(set) var isLocationAuthorized: Bool = false
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        checkAuthorizationStatus()
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func refreshWiFiInfo() {
        #if targetEnvironment(simulator)
        // Simulator always returns mock WiFi data without location permission
        currentWiFi = fetchWiFiInfo()
        #else
        guard isLocationAuthorized else {
            currentWiFi = nil
            return
        }
        currentWiFi = fetchWiFiInfo()
        #endif
    }

    private func checkAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
        isLocationAuthorized = authorizationStatus == .authorizedWhenInUse ||
                               authorizationStatus == .authorizedAlways

        #if targetEnvironment(simulator)
        // Auto-populate WiFi info in simulator
        refreshWiFiInfo()
        #else
        if isLocationAuthorized {
            refreshWiFiInfo()
        }
        #endif
    }
    
    private func fetchWiFiInfo() -> WiFiInfo? {
        #if targetEnvironment(simulator)
        return WiFiInfo(
            ssid: "Simulator WiFi",
            bssid: "00:00:00:00:00:00",
            signalStrength: nil,
            signalDBm: -45,
            channel: 6,
            frequency: nil,
            band: .band2_4GHz,
            securityType: "WPA3"
        )
        #else
        guard let interfaces = CNCopySupportedInterfaces() as? [String],
              let interface = interfaces.first,
              let info = CNCopyCurrentNetworkInfo(interface as CFString) as? [String: Any],
              let ssid = info[kCNNetworkInfoKeySSID as String] as? String else {
            return nil
        }

        let bssid = info[kCNNetworkInfoKeyBSSID as String] as? String

        return WiFiInfo(
            ssid: ssid,
            bssid: bssid,
            signalStrength: nil,
            signalDBm: nil,
            channel: nil,
            frequency: nil,
            band: nil,
            securityType: nil
        )
        #endif
    }
}

extension WiFiInfoService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            checkAuthorizationStatus()
        }
    }
}
