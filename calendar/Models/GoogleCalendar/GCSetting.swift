import Foundation

/// A Google Calendar user setting resource.
///
/// This is a 1:1 `Codable` representation of the `calendar#setting` JSON
/// returned by the Google Calendar API v3. Each setting is a key-value pair.
/// All fields are guaranteed present on read responses.
///
/// Known setting IDs include:
/// - `"autoAddHangouts"` -- automatically add video calls to events
/// - `"dateFieldOrder"` -- date field order (e.g. `"MDY"`, `"DMY"`, `"YMD"`)
/// - `"defaultEventLength"` -- default event duration in minutes
/// - `"format24HourTime"` -- whether to use 24-hour time (`"true"` / `"false"`)
/// - `"hideInvitations"` -- hide invitations from other users
/// - `"hideWeekends"` -- hide weekends in the calendar view
/// - `"locale"` -- user's locale (e.g. `"en"`)
/// - `"remindOnRespondedEventsOnly"` -- only remind on events the user has responded to
/// - `"showDeclinedEvents"` -- whether to show declined events
/// - `"timezone"` -- user's time zone (IANA identifier)
/// - `"useKeyboardShortcuts"` -- whether keyboard shortcuts are enabled
/// - `"weekStart"` -- day the week starts on (`"0"` = Sunday, `"1"` = Monday, `"6"` = Saturday)
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/settings#resource
nonisolated struct GCSetting: Codable, Sendable {

    /// Type of the resource. Always `"calendar#setting"`.
    let kind: String
    /// ETag of the resource.
    let etag: String
    /// The ID of the user setting. See type documentation for known IDs.
    let id: String
    /// The value of the user setting. Type and valid values depend on the setting `id`.
    let value: String
}
