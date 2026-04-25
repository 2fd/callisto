import Foundation

// MARK: - Calendar List Response

/// Paginated response from the `calendarList.list` endpoint.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/calendarList/list
nonisolated struct GCCalendarListResponse: Codable, Sendable {
    /// Type of the collection. Always `"calendar#calendarList"`.
    let kind: String
    /// ETag of the collection.
    let etag: String
    /// Token used to access the next page of results.
    /// Omitted if there are no further results, in which case `nextSyncToken` is provided.
    let nextPageToken: String?
    /// Token used at a later point in time to retrieve only the entries that have
    /// changed since this result was returned. Omitted if further results are available,
    /// in which case `nextPageToken` is provided.
    let nextSyncToken: String?
    /// Calendars and calendar subscriptions for the authenticated user.
    let items: [GCCalendarListEntry]
}

// MARK: - Events List Response

/// Paginated response from the `events.list` endpoint.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events/list
nonisolated struct GCEventsListResponse: Codable, Sendable {
    /// Type of the collection. Always `"calendar#events"`.
    let kind: String
    /// ETag of the collection.
    let etag: String
    /// Title of the calendar. Read-only.
    let summary: String?
    /// Description of the calendar. Read-only.
    let description: String?
    /// The time zone of the calendar. Read-only.
    let timeZone: String?
    /// The user's access role for this calendar. Read-only.
    /// Possible values: `"none"`, `"freeBusyReader"`, `"reader"`, `"writer"`, `"owner"`.
    let accessRole: String?
    /// Last modification time of the calendar (RFC 3339 timestamp). Read-only.
    let updated: String?
    /// Token used to access the next page of results.
    /// Omitted if there are no further results, in which case `nextSyncToken` is provided.
    let nextPageToken: String?
    /// Token used at a later point in time to retrieve only the entries that have
    /// changed since this result was returned. Omitted if further results are available,
    /// in which case `nextPageToken` is provided.
    let nextSyncToken: String?
    /// The default reminders on the calendar for the authenticated user.
    let defaultReminders: [GCReminder]?
    /// List of events on the calendar.
    let items: [GCEvent]
}

// MARK: - Settings List Response

/// Paginated response from the `settings.list` endpoint.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/settings/list
nonisolated struct GCSettingsListResponse: Codable, Sendable {
    /// Type of the collection. Always `"calendar#settings"`.
    let kind: String
    /// ETag of the collection.
    let etag: String
    /// Token used to access the next page of results.
    let nextPageToken: String?
    /// Token used at a later point in time to retrieve only the entries that have changed.
    let nextSyncToken: String?
    /// List of user settings.
    let items: [GCSetting]
}
