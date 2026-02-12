import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct NetmonitorApp: App {
    @AppStorage("selectedTheme") private var selectedTheme: String = "system"

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PairedMac.self,
            LocalDevice.self,
            MonitoringTarget.self,
            ToolResult.self,
            SpeedTestResult.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // App uses dark backgrounds exclusively — always force dark mode
    private var resolvedColorScheme: ColorScheme? {
        .dark
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedColorScheme)
                .accessibilityIdentifier("screen_main")
                .onAppear {
                    BackgroundTaskService.shared.registerTasks()
                    BackgroundTaskService.shared.scheduleRefreshTask()
                    BackgroundTaskService.shared.scheduleSyncTask()

                    // Prune data older than the configured retention period
                    let context = sharedModelContainer.mainContext
                    SettingsViewModel().pruneExpiredData(modelContext: context)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
