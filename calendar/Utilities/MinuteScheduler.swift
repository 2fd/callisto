import Foundation
import Observation

/// Publishes `now` when the wall clock flips to a new minute.
///
/// Views that render relative time (e.g. ``MenuBarLabel`` showing
/// "In 5min" / "Now") read `ticker.now` to register a dependency, so
/// SwiftUI re-renders them when the minute changes.
///
/// The stored `now` value is always rounded down to the latest exact minute
/// boundary. Each iteration checks the current wall clock once per second and
/// only publishes a new value when that minute boundary changes.
@MainActor @Observable
final class MinuteScheduler {
    private(set) var now: Date = Date.now.startOfMinute
    @ObservationIgnored private var task: Task<Void, Never>?

    func start() {
        stop()
        now = Date.now.startOfMinute
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }

                let currentMinute = Date.now.startOfMinute
                if self?.now != currentMinute {
                    self?.now = currentMinute
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
