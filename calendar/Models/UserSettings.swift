import Foundation
import SwiftUI
import Observation

// MARK: - SettingsStore Protocol

/// Abstracts key-value storage so ``UserSettings`` can be backed by
/// `UserDefaults` (production) or an in-memory store (tests / previews).
protocol SettingsStore {
    func integer(forKey key: String) -> Int
    func bool(forKey key: String) -> Bool
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: SettingsStore {}

/// A simple in-memory key-value store conforming to ``SettingsStore``.
///
/// Use this in tests and previews to avoid touching `UserDefaults`.
final class InMemorySettingsStore: SettingsStore {
    private var storage: [String: Any] = [:]

    func integer(forKey key: String) -> Int { storage[key] as? Int ?? 0 }
    func bool(forKey key: String) -> Bool { storage[key] as? Bool ?? false }
    func set(_ value: Any?, forKey key: String) { storage[key] = value }
}

// MARK: - UserSettings

/// User-facing preferences backed by a ``SettingsStore``.
///
/// All properties are **computed**, reading from and writing to the store
/// directly — there is no in-memory cache. Each accessor manually opts into
/// `@Observable` tracking via `access(keyPath:)` in the getter and
/// `withMutation(keyPath:)` in the setter. This is required because the
/// `@Observable` macro only auto-synthesizes tracking for *stored* properties;
/// computed properties that read from a non-observed source (here, `store`)
/// would otherwise never notify SwiftUI of changes, leaving views stale.
///
/// `@MainActor` because every consumer (views, managers) is main-actor-isolated.
@MainActor @Observable
final class UserSettings {

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    /// How often the sync timer polls the Google Calendar API, in minutes.
    ///
    /// Defaults to `5`. Clamped to a positive value by ``positiveInt(forKey:default:)``.
    var refreshIntervalMinutes: Int {
        get {
            access(keyPath: \.refreshIntervalMinutes)
            return positiveInt(forKey: DefaultsKey.refreshIntervalMinutes, default: 5)
        }
        set {
            withMutation(keyPath: \.refreshIntervalMinutes) {
                store.set(newValue, forKey: DefaultsKey.refreshIntervalMinutes)
            }
        }
    }

    /// Number of days into the future the popover shows events for.
    ///
    /// Defaults to `7`. Applied as a display filter in `CalendarStore.iter(settings:)`
    /// and `iterDays(settings:)` — does not affect what gets fetched from the server.
    var showDaysAhead: Int {
        get {
            access(keyPath: \.showDaysAhead)
            return positiveInt(forKey: DefaultsKey.showDaysAhead, default: 7)
        }
        set {
            withMutation(keyPath: \.showDaysAhead) {
                store.set(newValue, forKey: DefaultsKey.showDaysAhead)
            }
        }
    }

    /// Whether declined events should appear in the popover.
    ///
    /// Defaults to `false` (declined events are hidden).
    var showDeclinedEvents: Bool {
        get {
            access(keyPath: \.showDeclinedEvents)
            return store.bool(forKey: DefaultsKey.showDeclinedEvents)
        }
        set {
            withMutation(keyPath: \.showDeclinedEvents) {
                store.set(newValue, forKey: DefaultsKey.showDeclinedEvents)
            }
        }
    }

    /// Whether days with no events should still appear as empty sections.
    ///
    /// Defaults to `false` (empty days are collapsed out of the list).
    var showEmptyDays: Bool {
        get {
            access(keyPath: \.showEmptyDays)
            return store.bool(forKey: DefaultsKey.showEmptyDays)
        }
        set {
            withMutation(keyPath: \.showEmptyDays) {
                store.set(newValue, forKey: DefaultsKey.showEmptyDays)
            }
        }
    }

    /// Reads an `Int` from the store, substituting `defaultValue` when the
    /// stored value is missing or non-positive (UserDefaults returns `0` for
    /// unset keys, which is indistinguishable from an explicit zero).
    private func positiveInt(forKey key: String, default defaultValue: Int) -> Int {
        let value = store.integer(forKey: key)
        return value > 0 ? value : defaultValue
    }
}
