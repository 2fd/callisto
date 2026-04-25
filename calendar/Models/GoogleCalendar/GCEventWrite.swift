import Foundation

/// Request body used for writing to the Google Calendar `events` endpoints
/// (`insert`, `update`, `patch`, `import`).
///
/// All fields are optional with a `nil` default. Because `JSONEncoder` emits
/// optional properties via `encodeIfPresent`, unset fields are omitted — so
/// the same struct can serve as a full body for `insert`/`update` *and* as a
/// partial body for `patch` where only changed keys should be transmitted.
///
/// Read-only fields (`id` on insert, `etag`, `htmlLink`, `created`, `updated`,
/// `creator`, `organizer`, `hangoutLink`, `recurringEventId`, etc.) are
/// intentionally omitted.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events
nonisolated struct GCEventWrite: Codable, Sendable {
    /// Optional client-assigned opaque identifier. Only honored by
    /// `events.import`; ignored on `insert`.
    var id: String? = nil

    // MARK: - Content

    var summary: String? = nil
    var description: String? = nil
    var location: String? = nil
    var colorId: String? = nil

    // MARK: - Time

    var start: GCEventDateTime? = nil
    var end: GCEventDateTime? = nil
    var endTimeUnspecified: Bool? = nil
    var originalStartTime: GCEventDateTime? = nil

    // MARK: - Recurrence

    var recurrence: [String]? = nil

    // MARK: - Visibility & Transparency

    var transparency: String? = nil
    var visibility: String? = nil

    // MARK: - Attendees

    var attendees: [GCAttendee]? = nil
    var attendeesOmitted: Bool? = nil
    var anyoneCanAddSelf: Bool? = nil

    // MARK: - Conferencing

    var conferenceData: GCConferenceData? = nil

    // MARK: - Extended Properties

    var extendedProperties: GCExtendedProperties? = nil

    // MARK: - Guest Permissions

    var guestsCanInviteOthers: Bool? = nil
    var guestsCanModify: Bool? = nil
    var guestsCanSeeOtherGuests: Bool? = nil

    // MARK: - Reminders

    var reminders: GCReminders? = nil

    // MARK: - Source

    var source: GCSource? = nil

    // MARK: - Attachments

    var attachments: [GCAttachment]? = nil

    // MARK: - Event Type & Type-Specific Properties

    var eventType: String? = nil
    var workingLocationProperties: GCWorkingLocationProperties? = nil
    var outOfOfficeProperties: GCOutOfOfficeProperties? = nil
    var focusTimeProperties: GCFocusTimeProperties? = nil
    var birthdayProperties: GCBirthdayProperties? = nil
}

extension GCAttendee {
    /// Builds an attendee payload for write requests. Only `email` is required;
    /// all other fields default to `nil` so they're omitted from the JSON.
    static func write(
        email: String,
        responseStatus: String? = nil,
        displayName: String? = nil,
        optional: Bool? = nil,
        comment: String? = nil,
        additionalGuests: Int? = nil
    ) -> GCAttendee {
        GCAttendee(
            id: nil,
            email: email,
            displayName: displayName,
            organizer: nil,
            `self`: nil,
            resource: nil,
            optional: optional,
            responseStatus: responseStatus,
            comment: comment,
            additionalGuests: additionalGuests
        )
    }
}
