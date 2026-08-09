import Foundation

/// Drives periodic sync by invoking an action on an interval.
///
/// Owned by ``AppDelegate``. Starts once on launch (fires immediately then
/// every `intervalMinutes`) and is restarted when the user changes
/// ``UserSettings/refreshIntervalMinutes``.
@MainActor
final class SyncScheduler {
    private var task: Task<Void, Never>?

    func start(intervalMinutes: Int, action: @escaping @MainActor () async -> Void) {
        stop()
        let interval = TimeInterval(max(1, intervalMinutes) * 60)
        task = Task {
            await action()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { return }
                await action()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
