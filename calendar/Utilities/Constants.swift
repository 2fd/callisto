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

    /// Maximum simultaneous Google Calendar requests for a single account.
    ///
    /// Google's rate limit is enforced per user per project (600 requests per
    /// minute), so accounts do not contend with each other and only the
    /// per-account fan-out needs pacing. A user with dozens of calendars would
    /// otherwise open one connection per calendar every cycle.
    ///
    /// Reference: https://developers.google.com/workspace/calendar/api/guides/quota
    static let maxConcurrentRequestsPerAccount = 4

    /// How long an incremental cursor may be used before the whole window is
    /// re-read. Bounds the damage from any change an `updatedMin` query does
    /// not report, at the cost of one full read per calendar in that period.
    static let fullSyncInterval: TimeInterval = 6 * 60 * 60

    /// Overlap subtracted from the incremental cursor, absorbing clock skew
    /// between Google's `updated` stamps and ours.
    static let deltaSyncOverlap: TimeInterval = 5 * 60
}

/// How a calendar's events should be fetched this cycle.
enum EventSyncMode: Sendable, Equatable {
    /// Re-read the whole window. Events absent from the response are deleted.
    case full
    /// Fetch only what changed since `since`. The response is partial by
    /// definition, so absence means "unchanged" and must never trigger a delete;
    /// deletions arrive as `status: "cancelled"` tombstones instead.
    case delta(since: Date)

    var isFull: Bool {
        self == .full
    }

    /// The `updatedMin` value for this mode, if any.
    var updatedMin: Date? {
        switch self {
        case .full: nil
        case .delta(let since): since
        }
    }
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
