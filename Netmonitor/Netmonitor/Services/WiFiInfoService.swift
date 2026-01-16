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
        guard isLocationAuthorized else {
            currentWiFi = nil
            return
        }
        
        currentWiFi = fetchWiFiInfo()
    }
    
    private func checkAuthorizationStatus() {
        authorizationStatus = locationManager.authorizationStatus
        isLocationAuthorized = authorizationStatus == .authorizedWhenInUse ||
                               authorizationStatus == .authorizedAlways
        
        if isLocationAuthorized {
            refreshWiFiInfo()
        }
    }
    
    private func fetchWiFiInfo() -> WiFiInfo? {
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
    }
}

extension WiFiInfoService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            checkAuthorizationStatus()
        }
    }
}
