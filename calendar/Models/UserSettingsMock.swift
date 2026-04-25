#if DEBUG
import Foundation

/// Factory for creating configured `UserSettings` instances in tests and previews.
///
/// Uses ``InMemorySettingsStore`` so no `UserDefaults` are touched.
/// Every parameter has a sensible default so call sites only specify what they care about.
enum UserSettingsMock {

    // MARK: - Factory

    /// Creates a `UserSettings` with in-memory storage, populated with the given values.
    @MainActor
    static func make(
        refreshIntervalMinutes: Int = 5,
        showDaysAhead: Int = 7,
        showDeclinedEvents: Bool = false,
        showEmptyDays: Bool = false
    ) -> UserSettings {
        let settings = UserSettings(store: InMemorySettingsStore())
        settings.refreshIntervalMinutes = refreshIntervalMinutes
        settings.showDaysAhead = showDaysAhead
        settings.showDeclinedEvents = showDeclinedEvents
        settings.showEmptyDays = showEmptyDays
        return settings
    }

    // MARK: - Presets

    /// Out-of-box defaults (equivalent to a fresh install).
    @MainActor
    static func defaults() -> UserSettings {
        make()
    }

    /// Non-default values for all properties — useful for testing that custom
    /// settings are respected rather than hard-coded defaults being used.
    @MainActor
    static func custom(
        refreshIntervalMinutes: Int = 15,
        showDaysAhead: Int = 14,
        showDeclinedEvents: Bool = true,
        showEmptyDays: Bool = true,
    ) -> UserSettings {
        make(
            refreshIntervalMinutes: refreshIntervalMinutes,
            showDaysAhead: showDaysAhead,
            showDeclinedEvents: showDeclinedEvents,
        showEmptyDays: showEmptyDays,
        )
    }
}
#endif
