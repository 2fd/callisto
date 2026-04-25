import Foundation

/// A complete Google Calendar calendar list entry resource.
///
/// This is a 1:1 `Codable` representation of the `calendar#calendarListEntry` JSON
/// returned by the Google Calendar API v3. Fields guaranteed by the API on every
/// read response are non-optional; all others are optional for forward compatibility.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/calendarList#resource
nonisolated struct GCCalendarListEntry: Codable, Sendable {

    // MARK: - Metadata (always present on read)

    /// Type of the resource. Always `"calendar#calendarListEntry"`.
    let kind: String
    /// ETag of the resource.
    let etag: String
    /// Identifier of the calendar.
    let id: String

    // MARK: - Content

    /// Title of the calendar. Read-only.
    let summary: String?
    /// Description of the calendar. Read-only.
    let description: String?
    /// Geographic location of the calendar as free-form text. Read-only.
    let location: String?
    /// The time zone of the calendar. Read-only.
    let timeZone: String?

    // MARK: - Appearance

    /// The summary that the authenticated user has set for this calendar.
    /// If not set, falls back to `summary`.
    let summaryOverride: String?
    /// The color ID of the calendar. Refers to an entry in the `calendar`
    /// section of the colors definition. Writable.
    let colorId: String?
    /// The main color of the calendar in hexadecimal format (e.g. `"#0088aa"`).
    /// This is the effective color, taking into account `colorId` overrides. Read-only.
    let backgroundColor: String?
    /// The foreground color of the calendar in hexadecimal format (e.g. `"#ffffff"`). Read-only.
    let foregroundColor: String?

    // MARK: - Visibility & Selection

    /// Whether the calendar has been hidden from the list. The default is `false`.
    let hidden: Bool?
    /// Whether the calendar content shows up in the calendar UI. The default is `false`.
    let selected: Bool?
    /// Whether this calendar is the primary calendar of the authenticated user. Read-only.
    let primary: Bool?
    /// Whether this calendar list entry has been deleted from the calendar list. Read-only.
    let deleted: Bool?

    // MARK: - Access

    /// The effective access role that the authenticated user has on the calendar.
    /// Possible values: `"freeBusyReader"`, `"reader"`, `"writer"`, `"owner"`. Read-only.
    let accessRole: String

    // MARK: - Reminders

    /// The default reminders that the authenticated user has for this calendar.
    let defaultReminders: [GCReminder]?

    // MARK: - Notifications

    /// The notifications that the authenticated user is receiving for this calendar.
    let notificationSettings: NotificationSettings?

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

// MARK: - Notification Settings

extension GCCalendarListEntry {
    /// Notification settings for a calendar.
    nonisolated struct NotificationSettings: Codable, Sendable {
        /// The list of notifications set for this calendar.
        let notifications: [Notification]?

        /// A single notification on a calendar.
        nonisolated struct Notification: Codable, Sendable {
            /// The type of notification.
            /// Possible values: `"eventCreation"`, `"eventChange"`, `"eventCancellation"`,
            /// `"eventResponse"`, `"agenda"`.
            let type: String?
            /// The method used to deliver the notification.
            /// Possible values: `"email"`.
            let method: String?
        }
    }
}
