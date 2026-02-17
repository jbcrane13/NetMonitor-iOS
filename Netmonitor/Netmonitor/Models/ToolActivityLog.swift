import Foundation

/// Shared log of recent tool activity, observable by any view.
/// Individual tool ViewModels post results here; ToolsView displays them.
@MainActor @Observable
final class ToolActivityLog {
    static let shared = ToolActivityLog()

    private(set) var entries: [ToolActivityItem] = []
    private let maxEntries = 20

    private init() {}

    func add(tool: String, target: String, result: String, success: Bool) {
        let item = ToolActivityItem(
            tool: tool,
            target: target,
            result: result,
            success: success,
            timestamp: Date()
        )
        entries.insert(item, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
    }

    func clear() {
        entries = []
    }
}
