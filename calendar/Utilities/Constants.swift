import Foundation

/// Shared constants used across the app to avoid stringly-typed values.
enum Constants {

    /// The bundle identifier / logger subsystem.
    static let subsystem = "dev.frami.callisto"

    /// Default Google Calendar color (Google blue).
    static let defaultCalendarColor = "#4285F4"

    /// Number of days the sync service always fetches from Google Calendar API.
    ///
    /// Display-layer limits (``AppSettings/showDaysAhead``) are applied at render time,
    /// so the local SwiftData cache always has a full month of data available.
    static let syncFetchDays = 31
}

enum UI {
    static let Width = CGFloat(280)
}

/// UserDefaults keys, centralized to prevent typos.
enum DefaultsKey {
    static let refreshIntervalMinutes = "refreshIntervalMinutes"
    static let showDaysAhead = "showDaysAhead"
    static let showDeclinedEvents = "showDeclinedEvents"
    static let showEmptyDays = "showEmptyDays"
}

/// Google Calendar event status values returned by the API.
enum EventStatus {
    // Event-level statuses
    static let cancelled = "cancelled"
    static let confirmed = "confirmed"
    static let tentative = "tentative"

    // Attendee response statuses
    static let accepted = "accepted"
    static let needsAction = "needsAction"
    static let declined = "declined"
}

/// Google Calendar event type values returned by the API.
enum EventType {
    static let `default` = "default"
    static let outOfOffice = "outOfOffice"
    static let focusTime = "focusTime"
    static let workingLocation = "workingLocation"
    static let birthday = "birthday"
    static let fromGmail = "fromGmail"
}
