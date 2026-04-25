import Foundation
import SwiftData

/// A Google Calendar belonging to a ``GoogleAccount``.
///
/// Synced from the Google Calendar API `calendarList` endpoint. Persists the
/// subset of `calendar#calendarListEntry` fields the app uses, plus an
/// app-local ``isVisible`` flag the user toggles in settings.
@Model
final class GoogleCalendar {
    #Unique<GoogleCalendar>([\.calendarId])

    // MARK: - Identity

    @Attribute(.unique) var calendarId: String
    /// ID of the ``GoogleAccount`` that owns this calendar.
    var accountId: String
    /// ETag for conditional sync / conflict detection.
    var etag: String

    // MARK: - Content

    var summary: String
    var calendarDescription: String?
    var location: String?
    var timeZone: String?

    // MARK: - Appearance

    var summaryOverride: String?
    var colorId: String?
    var backgroundColor: String
    var foregroundColor: String?

    // MARK: - Flags

    /// Whether this is the user's primary calendar.
    var isPrimary: Bool = false
    /// The user's access role: `"freeBusyReader"`, `"reader"`, `"writer"`, or `"owner"`.
    var accessRole: String

    // MARK: - App-local state (not synced)

    /// User setting: when `false`, events from this calendar are filtered out of the popover.
    /// Display-only filter — disabled calendars still sync from Google.
    var isVisible: Bool = true

    /// Timestamp of the last successful fetch from `calendarList`, or `nil` if never synced.
    var lastSyncedAt: Date?

    // MARK: - Computed

    var displayName: String { summaryOverride ?? summary }

    // MARK: - Init

    init(
        calendarId: String,
        accountId: String,
        etag: String = "",
        summary: String = "",
        backgroundColor: String = Constants.defaultCalendarColor,
        accessRole: String = "reader",
        isVisible: Bool = true
    ) {
        self.calendarId = calendarId
        self.accountId = accountId
        self.etag = etag
        self.summary = summary
        self.backgroundColor = backgroundColor
        self.accessRole = accessRole
        self.isVisible = isVisible
    }

    convenience init(from entry: GCCalendarListEntry, accountId: String, isVisible: Bool = true) {
        self.init(
            calendarId: entry.id,
            accountId: accountId,
            etag: entry.etag,
            summary: entry.summary ?? "Untitled",
            backgroundColor: entry.backgroundColor ?? Constants.defaultCalendarColor,
            accessRole: entry.accessRole,
            isVisible: isVisible
        )
        apply(entry)
        lastSyncedAt = .now
    }

    /// Updates mutable fields from a sync entry, preserving user-controlled ``isVisible``.
    func update(from entry: GCCalendarListEntry) {
        etag = entry.etag
        summary = entry.summary ?? summary
        backgroundColor = entry.backgroundColor ?? backgroundColor
        accessRole = entry.accessRole
        apply(entry)
        lastSyncedAt = .now
    }

    private func apply(_ entry: GCCalendarListEntry) {
        calendarDescription = entry.description
        location = entry.location
        timeZone = entry.timeZone
        summaryOverride = entry.summaryOverride
        colorId = entry.colorId
        foregroundColor = entry.foregroundColor
        isPrimary = entry.primary ?? false
    }
}
