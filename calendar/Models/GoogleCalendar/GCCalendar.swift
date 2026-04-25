import Foundation

/// A complete Google Calendar calendar resource.
///
/// This is a 1:1 `Codable` representation of the `calendar#calendar` JSON
/// returned by the Google Calendar API v3. Fields guaranteed by the API on every
/// read response are non-optional; all others are optional for forward compatibility.
///
/// Note: This represents the raw calendar metadata from the Calendars endpoint,
/// not the user-specific view from CalendarList. For user-specific properties
/// (color, visibility, notifications), see ``GCCalendarListEntry``.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/calendars#resource
nonisolated struct GCCalendar: Codable, Sendable {

    // MARK: - Metadata (always present on read)

    /// Type of the resource. Always `"calendar#calendar"`.
    let kind: String
    /// ETag of the resource.
    let etag: String
    /// Identifier of the calendar. For the primary calendar, use `"primary"`.
    let id: String

    // MARK: - Content

    /// Title of the calendar.
    let summary: String?
    /// Description of the calendar.
    let description: String?
    /// Geographic location of the calendar as free-form text.
    let location: String?
    /// The time zone of the calendar (IANA time zone identifier, e.g. `"America/Los_Angeles"`).
    let timeZone: String?

    // MARK: - Conference

    /// Conferencing properties for this calendar.
    let conferenceProperties: GCConferenceProperties?

    // MARK: - Ownership

    /// The data owner of the calendar.
    /// Possible values: `"user"`, `"domain"`, `"organization"`.
    let dataOwner: String?
    /// Whether auto-accept invitations is enabled for this calendar.
    let autoAcceptInvitations: Bool?
}
