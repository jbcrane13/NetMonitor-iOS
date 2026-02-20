import Foundation
import BackgroundTasks
import SwiftData
import NetworkScanKit
import WidgetKit
import Network
import os

/// Manages background task scheduling for periodic network checks.
///
/// Deliberately NOT `@MainActor` — BGTaskScheduler callbacks are `@Sendable`
/// and run on arbitrary queues. MainActor-isolated services are accessed
/// explicitly via `await MainActor.run { }` where needed.
final class BackgroundTaskService: Sendable {
    static let shared = BackgroundTaskService()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.blakemiller.netmonitor", category: "BackgroundTaskService")

    static let refreshTaskIdentifier = "com.blakemiller.netmonitor.refresh"
    static let syncTaskIdentifier = "com.blakemiller.netmonitor.sync"

    private init() {}

    // MARK: - Registration

    /// Register background tasks with the system.
    /// Called from MainActor context (App.onAppear) but the registration
    /// callbacks themselves are @Sendable and run on dispatch queues.
    /// Wrapper to safely pass BGTask across isolation boundaries.
    /// BGTask is not Sendable but BGTaskScheduler guarantees single-owner
    /// semantics: the callback receives exclusive ownership of the task.
    private struct UncheckedBGTask<T: BGTask>: @unchecked Sendable {
        let task: T
    }

    nonisolated func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) { [self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                Self.logger.error("Unexpected task type for refresh: \(type(of: task))")
                task.setTaskCompleted(success: false)
                return
            }
            let wrapped = UncheckedBGTask(task: refreshTask)
            Task { await self.handleRefreshTask(wrapped.task) }
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.syncTaskIdentifier, using: nil) { [self] task in
            guard let processingTask = task as? BGProcessingTask else {
                Self.logger.error("Unexpected task type for sync: \(type(of: task))")
                task.setTaskCompleted(success: false)
                return
            }
            let wrapped = UncheckedBGTask(task: processingTask)
            Task { await self.handleSyncTask(wrapped.task) }
        }
    }

    // MARK: - Scheduling

    nonisolated func scheduleRefreshTask() {
        let enabled = UserDefaults.standard.object(forKey: AppSettings.Keys.backgroundRefreshEnabled) as? Bool ?? true
        guard enabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshTaskIdentifier)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)

        // Respect user's refresh interval setting, but enforce BGTaskScheduler minimum of 15 minutes
        let userInterval = UserDefaults.standard.integer(forKey: AppSettings.Keys.autoRefreshInterval)
        let interval = userInterval > 0 ? TimeInterval(userInterval) : 60
        let effectiveInterval = max(15 * 60, interval)

        request.earliestBeginDate = Date(timeIntervalSinceNow: effectiveInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Self.logger.error("Failed to schedule refresh task: \(error)")
        }
    }

    nonisolated func scheduleSyncTask() {
        let request = BGProcessingTaskRequest(identifier: Self.syncTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Self.logger.error("Failed to schedule sync task: \(error)")
        }
    }

    // MARK: - Task Handlers

    /// Thread-safe cancellation flag for background tasks.
    private final class CancellationState: @unchecked Sendable {
        private let lock = OSAllocatedUnfairLock(initialState: false)

        var isCancelled: Bool {
            lock.withLock { $0 }
        }

        func cancel() {
            lock.withLock { $0 = true }
        }
    }

    /// Thread-safe single-fire completion for BGTask.
    private final class CompletionGuard: @unchecked Sendable {
        private let lock = OSAllocatedUnfairLock(initialState: false)
        private let task: BGTask

        init(task: BGTask) {
            self.task = task
        }

        func complete(success: Bool) {
            let shouldComplete = lock.withLock { didComplete -> Bool in
                guard !didComplete else { return false }
                didComplete = true
                return true
            }
            if shouldComplete {
                task.setTaskCompleted(success: success)
            }
        }
    }

    private func handleRefreshTask(_ task: BGAppRefreshTask) async {
        // Schedule the next refresh
        scheduleRefreshTask()

        let cancellation = CancellationState()
        let completion = CompletionGuard(task: task)

        task.expirationHandler = {
            cancellation.cancel()
            completion.complete(success: false)
        }

        defer {
            completion.complete(success: !cancellation.isCancelled)
        }

        // Perform network checks on MainActor where the services live
        await MainActor.run {
            let _ = NetworkMonitorService.shared // ensure started
        }

        let gatewayService = await MainActor.run { GatewayService() }
        await gatewayService.detectGateway()

        // Update shared UserDefaults for widget
        await MainActor.run {
            let networkMonitor = NetworkMonitorService.shared
            let defaults = UserDefaults(suiteName: AppSettings.appGroupSuiteName) ?? .standard
            defaults.set(networkMonitor.isConnected, forKey: AppSettings.Keys.widgetIsConnected)
            defaults.set(networkMonitor.connectionType.displayName, forKey: AppSettings.Keys.widgetConnectionType)

            if let gateway = gatewayService.gateway {
                defaults.set(gateway.latencyText, forKey: AppSettings.Keys.widgetGatewayLatency)

                if let latency = gateway.latency {
                    NotificationService.shared.notifyHighLatency(host: gateway.ipAddress, latency: latency)
                }
            }
        }

        guard !cancellation.isCancelled else { return }
        await checkMonitoringTargets()

        guard !cancellation.isCancelled else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func handleSyncTask(_ task: BGProcessingTask) async {
        // Schedule the next sync
        scheduleSyncTask()

        let cancellation = CancellationState()
        let completion = CompletionGuard(task: task)

        task.expirationHandler = {
            cancellation.cancel()
            completion.complete(success: false)
        }

        defer {
            completion.complete(success: !cancellation.isCancelled)
        }

        let gatewayService = await MainActor.run { GatewayService() }
        let publicIPService = await MainActor.run { PublicIPService() }

        // Full network check
        await gatewayService.detectGateway()

        guard !cancellation.isCancelled else { return }
        await publicIPService.fetchPublicIP(forceRefresh: true)

        // Update shared UserDefaults for widget
        await MainActor.run {
            let networkMonitor = NetworkMonitorService.shared
            let defaults = UserDefaults(suiteName: AppSettings.appGroupSuiteName) ?? .standard
            defaults.set(networkMonitor.isConnected, forKey: AppSettings.Keys.widgetIsConnected)
            defaults.set(networkMonitor.connectionType.displayName, forKey: AppSettings.Keys.widgetConnectionType)

            if let gateway = gatewayService.gateway {
                defaults.set(gateway.latencyText, forKey: AppSettings.Keys.widgetGatewayLatency)
            }

            if let isp = publicIPService.ispInfo {
                defaults.set(isp.publicIP, forKey: AppSettings.Keys.widgetPublicIP)
            }
        }

        guard !cancellation.isCancelled else { return }
        await checkMonitoringTargets()

        guard !cancellation.isCancelled else { return }
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Monitoring Target Checks

    private func checkMonitoringTargets() async {
        // Create a new ModelContainer for background context with full schema
        let schema = Schema([
            PairedMac.self, LocalDevice.self, MonitoringTarget.self,
            ToolResult.self, SpeedTestResult.self
        ])
        guard let modelContainer = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
        ) else {
            Self.logger.error("Failed to create ModelContainer for background task")
            return
        }

        // SwiftData @Model objects are @MainActor — access via MainActor
        await MainActor.run {
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<MonitoringTarget>(
                predicate: #Predicate { $0.isEnabled }
            )

            guard let targets = try? context.fetch(descriptor) else {
                Self.logger.error("Failed to fetch monitoring targets")
                return
            }

            // Collect target info for non-isolated network checks
            // We'll update the models back on MainActor after checking
            _ = targets  // will be used in place since we're already on MainActor
        }

        // For monitoring targets, we need to fetch, check, and update all on MainActor
        // since @Model objects can't cross isolation boundaries
        await performTargetChecks(container: modelContainer)
    }

    private func performTargetChecks(container: ModelContainer) async {
        // Fetch targets on MainActor, extract Sendable data for network checks
        struct TargetInfo: Sendable {
            let persistentModelID: PersistentIdentifier
            let host: String
            let port: Int?
            let timeout: TimeInterval
            let targetProtocol: String  // Use string to avoid Sendable issues
            let isOnline: Bool
            let name: String
        }

        let targetInfos: [TargetInfo] = await MainActor.run {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<MonitoringTarget>(
                predicate: #Predicate { $0.isEnabled }
            )
            guard let targets = try? context.fetch(descriptor) else { return [] }
            return targets.map { target in
                TargetInfo(
                    persistentModelID: target.persistentModelID,
                    host: target.host,
                    port: target.port,
                    timeout: target.timeout,
                    targetProtocol: target.targetProtocol.rawValue,
                    isOnline: target.isOnline,
                    name: target.name
                )
            }
        }

        // Perform network checks outside MainActor (no isolation needed)
        var results: [(PersistentIdentifier, Bool, Double?)] = []
        for info in targetInfos {
            let checkResult = await checkTargetInfo(
                host: info.host,
                port: info.port,
                timeout: info.timeout,
                protocol: info.targetProtocol
            )
            results.append((info.persistentModelID, checkResult.success, checkResult.latency))

            // Send notifications for status changes
            if checkResult.success, let latency = checkResult.latency {
                await MainActor.run {
                    NotificationService.shared.notifyHighLatency(host: info.host, latency: latency)
                }
            } else if info.isOnline {
                // Was online, check failed — might be going down
                await MainActor.run {
                    NotificationService.shared.notifyTargetDown(name: info.name, host: info.host)
                }
            }
        }

        // Update models back on MainActor
        await MainActor.run {
            let context = ModelContext(container)
            for (modelID, success, latency) in results {
                guard let target = try? context.model(for: modelID) as? MonitoringTarget else { continue }
                if success, let latency {
                    target.recordSuccess(latency: latency)
                } else {
                    target.recordFailure()
                }
            }
            try? context.save()
        }
    }

    private nonisolated func checkTargetInfo(
        host: String, port: Int?, timeout: TimeInterval, protocol proto: String
    ) async -> (success: Bool, latency: Double?) {
        let startTime = Date()

        switch proto {
        case "tcp":
            let effectivePort = port ?? 80
            let result = await tcpConnect(host: host, port: effectivePort, timeout: timeout)
            let latency = result ? Date().timeIntervalSince(startTime) * 1000 : nil
            return (result, latency)

        case "http", "https":
            let result = await httpCheck(host: host, port: port, isHTTPS: proto == "https", timeout: timeout)
            let latency = result ? Date().timeIntervalSince(startTime) * 1000 : nil
            return (result, latency)

        case "icmp":
            // ICMP requires raw sockets which may not work in background
            // Fall back to TCP probe on a common port
            let effectivePort = port ?? 80
            let result = await tcpConnect(host: host, port: effectivePort, timeout: timeout)
            let latency = result ? Date().timeIntervalSince(startTime) * 1000 : nil
            return (result, latency)

        default:
            return (false, nil)
        }
    }

    private nonisolated func tcpConnect(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        // Use a Sendable helper to bridge NWConnection's callback-based API
        // into async/await without crossing isolation boundaries.
        let probe = TCPProbe(host: host, port: UInt16(port), timeout: timeout)
        return await probe.run()
    }
}

/// Sendable helper that owns an NWConnection for a single TCP probe.
/// All state mutation is protected by `OSAllocatedUnfairLock`.
private final class TCPProbe: @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private let timeout: TimeInterval
    private let completed = OSAllocatedUnfairLock(initialState: false)
    private var connection: NWConnection?

    init(host: String, port: UInt16, timeout: TimeInterval) {
        self.host = host
        self.port = port
        self.timeout = timeout
    }

    func run() async -> Bool {
        await withCheckedContinuation { continuation in
            let conn = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: port),
                using: .tcp
            )
            self.connection = conn

            // Single-fire resume
            let finish: @Sendable (Bool) -> Void = { [weak self] value in
                guard let self else { return }
                let shouldResume = self.completed.withLock { done -> Bool in
                    guard !done else { return false }
                    done = true
                    return true
                }
                if shouldResume {
                    self.connection?.cancel()
                    self.connection = nil
                    continuation.resume(returning: value)
                }
            }

            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                finish(false)
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }

            conn.start(queue: .global())
        }
    }
}

// MARK: - HTTP Check (extension on BackgroundTaskService)

extension BackgroundTaskService {
    fileprivate nonisolated func httpCheck(host: String, port: Int?, isHTTPS: Bool, timeout: TimeInterval) async -> Bool {
        let scheme = isHTTPS ? "https" : "http"
        let effectivePort = port ?? (isHTTPS ? 443 : 80)
        let urlString = "\(scheme)://\(host):\(effectivePort)"

        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return (200...399).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            return false
        }
    }
}
