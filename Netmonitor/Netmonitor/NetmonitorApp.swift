import SwiftUI
import SwiftData

@main
struct NetmonitorApp: App {
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .accessibilityIdentifier("screen_main")
        }
        .modelContainer(sharedModelContainer)
    }
}
