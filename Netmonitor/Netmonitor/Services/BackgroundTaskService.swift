import Foundation
import BackgroundTasks
import SwiftData
import WidgetKit

/// Manages background task scheduling for periodic network checks
@MainActor
final class BackgroundTaskService {
    static let shared = BackgroundTaskService()

    static let refreshTaskIdentifier = "com.blakemiller.netmonitor.refresh"
    static let syncTaskIdentifier = "com.blakemiller.netmonitor.sync"

    private init() {}

    // MARK: - Registration

    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) { task in
            Task { @MainActor in
                await self.handleRefreshTask(task as! BGAppRefreshTask)
            }
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.syncTaskIdentifier, using: nil) { task in
            Task { @MainActor in
                await self.handleSyncTask(task as! BGProcessingTask)
            }
        }
    }

    // MARK: - Scheduling

    func scheduleRefreshTask() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule refresh task: \(error)")
        }
    }

    func scheduleSyncTask() {
        let request = BGProcessingTaskRequest(identifier: Self.syncTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule sync task: \(error)")
        }
    }

    // MARK: - Task Handlers

    private func handleRefreshTask(_ task: BGAppRefreshTask) async {
        // Schedule the next refresh
        scheduleRefreshTask()

        let networkMonitor = NetworkMonitorService()
        let gatewayService = GatewayService()

        // Check network status and update widget data
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        await gatewayService.detectGateway()

        // Update shared UserDefaults for widget
        let defaults = UserDefaults(suiteName: "group.com.blakemiller.netmonitor") ?? .standard
        defaults.set(networkMonitor.isConnected, forKey: "widget_isConnected")
        defaults.set(networkMonitor.connectionType.displayName, forKey: "widget_connectionType")

        if let gateway = gatewayService.gateway {
            defaults.set(gateway.latencyText, forKey: "widget_gatewayLatency")
        }

        // Reload widget timeline
        WidgetCenter.shared.reloadAllTimelines()

        task.setTaskCompleted(success: true)
    }

    private func handleSyncTask(_ task: BGProcessingTask) async {
        // Schedule the next sync
        scheduleSyncTask()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        let networkMonitor = NetworkMonitorService()
        let gatewayService = GatewayService()
        let publicIPService = PublicIPService()

        // Full network check
        await gatewayService.detectGateway()
        await publicIPService.fetchPublicIP(forceRefresh: true)

        // Update shared UserDefaults for widget
        let defaults = UserDefaults(suiteName: "group.com.blakemiller.netmonitor") ?? .standard
        defaults.set(networkMonitor.isConnected, forKey: "widget_isConnected")
        defaults.set(networkMonitor.connectionType.displayName, forKey: "widget_connectionType")

        if let gateway = gatewayService.gateway {
            defaults.set(gateway.latencyText, forKey: "widget_gatewayLatency")
        }

        if let isp = publicIPService.ispInfo {
            defaults.set(isp.publicIP, forKey: "widget_publicIP")
        }

        // Reload widget timeline
        WidgetCenter.shared.reloadAllTimelines()

        task.setTaskCompleted(success: true)
    }
}
