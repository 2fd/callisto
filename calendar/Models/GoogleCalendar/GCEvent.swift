import Foundation

/// A complete Google Calendar event resource.
///
/// This is a 1:1 `Codable` representation of the `calendar#event` JSON returned
/// by the Google Calendar API v3. Fields guaranteed by the API on every read
/// response are non-optional; all others are optional for forward compatibility
/// and to handle partial/cancelled event responses.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCEvent: Codable, Sendable {

    // MARK: - Metadata (always present on read)

    /// Type of the resource. Always `"calendar#event"`.
    let kind: String
    /// ETag of the resource.
    let etag: String
    /// Opaque identifier of the event within a calendar. Immutable.
    let id: String
    /// Status of the event. Possible values: `"confirmed"`, `"tentative"`, `"cancelled"`.
    let status: String
    /// iCalendar UID of the event. Unique across calendars per RFC 5545.
    let iCalUID: String
    /// Sequence number as per iCalendar specification.
    let sequence: Int

    // MARK: - Metadata (may be absent on minimal cancelled stubs)

    /// URL to view the event in Google Calendar.
    let htmlLink: String?
    /// Creation time of the event (RFC 3339 timestamp). Read-only.
    let created: String?
    /// Last modification time of the event (RFC 3339 timestamp). Read-only.
    let updated: String?

    // MARK: - Content

    /// Title of the event.
    let summary: String?
    /// Description of the event. Can contain HTML.
    let description: String?
    /// Geographic location of the event as free-form text.
    let location: String?
    /// The color ID of the event. Refers to an entry in the `event` section
    /// of the colors definition (see the colors endpoint).
    let colorId: String?

    // MARK: - People

    /// The creator of the event. Read-only.
    let creator: GCPerson?
    /// The organizer of the event.
    let organizer: GCPerson?

    // MARK: - Time

    /// The (inclusive) start time of the event.
    let start: GCEventDateTime?
    /// The (exclusive) end time of the event.
    let end: GCEventDateTime?
    /// Whether the end time is actually unspecified.
    /// An event where `endTimeUnspecified` is true is treated as lasting all day.
    let endTimeUnspecified: Bool?

    // MARK: - Recurrence

    /// List of RRULE, EXRULE, RDATE and EXDATE lines for a recurring event.
    /// This field is omitted for single events and instances of recurring events.
    let recurrence: [String]?
    /// For an instance of a recurring event, this is the `id` of the recurring
    /// event to which this instance belongs. Immutable.
    let recurringEventId: String?
    /// For an instance of a recurring event, this is the time at which this event
    /// would start according to the recurrence data in the recurring event.
    let originalStartTime: GCEventDateTime?

    // MARK: - Visibility & Transparency

    /// Whether the event blocks time on the calendar.
    /// Possible values: `"opaque"` (default, blocks time), `"transparent"` (does not block time).
    let transparency: String?
    /// Visibility of the event.
    /// Possible values: `"default"`, `"public"`, `"private"`, `"confidential"`.
    let visibility: String?

    // MARK: - Attendees

    /// The attendees of the event.
    let attendees: [GCAttendee]?
    /// Whether attendees may have been omitted from the event's representation.
    let attendeesOmitted: Bool?

    // MARK: - Conferencing

    /// An absolute link to the Google Hangouts conference associated with this event. Read-only.
    let hangoutLink: String?
    /// The conference-related information, such as entry points and solution details.
    let conferenceData: GCConferenceData?

    // MARK: - Extended Properties

    /// Extended properties of the event (private and shared key-value pairs).
    let extendedProperties: GCExtendedProperties?

    // MARK: - Gadget (deprecated)

    /// A gadget that extends this event. Deprecated.
    let gadget: GCGadget?

    // MARK: - Guest Permissions

    /// Whether anyone can invite themselves to the event (deprecated). Default: false.
    let anyoneCanAddSelf: Bool?
    /// Whether attendees other than the organizer can invite others. Default: true.
    let guestsCanInviteOthers: Bool?
    /// Whether attendees other than the organizer can modify the event. Default: false.
    let guestsCanModify: Bool?
    /// Whether attendees other than the organizer can see the attendee list. Default: true.
    let guestsCanSeeOtherGuests: Bool?
    /// Whether this is a private event copy where changes are not shared with others. Default: false.
    let privateCopy: Bool?
    /// Whether this is a locked event copy where no changes can be made. Default: false.
    let locked: Bool?

    // MARK: - Reminders

    /// Information about the event's reminders.
    let reminders: GCReminders?

    // MARK: - Source

    /// Source from which the event was created (e.g. a web page or email message).
    let source: GCSource?

    // MARK: - Attachments

    /// File attachments for the event. Max 25 per event.
    let attachments: [GCAttachment]?

    // MARK: - Event Type & Type-Specific Properties

    /// Specific type of the event. Always present; defaults to `"default"`.
    /// Possible values: `"default"`, `"outOfOffice"`, `"focusTime"`,
    /// `"workingLocation"`, `"birthday"`, `"fromGmail"`.
    let eventType: String

    /// Working location properties. Only populated when `eventType` is `"workingLocation"`.
    let workingLocationProperties: GCWorkingLocationProperties?
    /// Out of office properties. Only populated when `eventType` is `"outOfOffice"`.
    let outOfOfficeProperties: GCOutOfOfficeProperties?
    /// Focus time properties. Only populated when `eventType` is `"focusTime"`.
    let focusTimeProperties: GCFocusTimeProperties?
    /// Birthday properties. Only populated when `eventType` is `"birthday"`.
    let birthdayProperties: GCBirthdayProperties?
}

// MARK: - Attendee

/// A single attendee on a Google Calendar event.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCAttendee: Codable, Sendable {
    /// The attendee's Profile ID, if available.
    let id: String?
    /// The attendee's email address, if available.
    let email: String?
    /// The attendee's name, if available.
    let displayName: String?
    /// Whether the attendee is the organizer of the event.
    let organizer: Bool?
    /// Whether this entry represents the calendar on which the event appears.
    let `self`: Bool?
    /// Whether the attendee is a resource (e.g. a conference room).
    let resource: Bool?
    /// Whether this is an optional attendee.
    let `optional`: Bool?
    /// The attendee's response status.
    /// Possible values: `"needsAction"`, `"declined"`, `"tentative"`, `"accepted"`.
    let responseStatus: String?
    /// The attendee's response comment.
    let comment: String?
    /// Number of additional guests the attendee is bringing. Default: 0.
    let additionalGuests: Int?
}

// MARK: - Extended Properties

/// Extended properties of the event (private and shared key-value pairs).
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCExtendedProperties: Codable, Sendable {
    /// Properties that are private to the copy of the event that appears on this calendar.
    let privateProperties: [String: String]?
    /// Properties that are shared between copies of the event on other attendees' calendars.
    let shared: [String: String]?

    enum CodingKeys: String, CodingKey {
        case privateProperties = "private"
        case shared
    }
}

// MARK: - Gadget (deprecated)

/// A gadget that extends an event. Deprecated by Google.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCGadget: Codable, Sendable {
    /// The gadget's type. Deprecated.
    let type: String?
    /// The gadget's title. Deprecated.
    let title: String?
    /// The gadget's URL. Deprecated.
    let link: String?
    /// The gadget's icon URL. Deprecated.
    let iconLink: String?
    /// The gadget's width in pixels. Deprecated.
    let width: Int?
    /// The gadget's height in pixels. Deprecated.
    let height: Int?
    /// The gadget's display mode. Deprecated.
    let display: String?
    /// Preferences for the gadget. Deprecated.
    let preferences: [String: String]?
}

// MARK: - Reminders

/// Information about the event's reminders.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCReminders: Codable, Sendable {
    /// Whether the default reminders of the calendar apply to the event.
    let useDefault: Bool?
    /// If the event doesn't use the default reminders, this lists the reminders
    /// specific to the event. If not set, no reminders apply.
    let overrides: [GCReminder]?
}

// MARK: - Source

/// Source from which the event was created.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCSource: Codable, Sendable {
    /// URL of the source pointing to a resource. The URL scheme must be HTTP or HTTPS.
    let url: String?
    /// Title of the source (e.g. the title of a web page or an email subject).
    let title: String?
}

// MARK: - Attachment

/// A file attachment on a Google Calendar event.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCAttachment: Codable, Sendable {
    /// URL link to the attachment.
    let fileUrl: String?
    /// Attachment title.
    let title: String?
    /// Internet media type (MIME type) of the attachment.
    let mimeType: String?
    /// URL link to the attachment's icon.
    let iconLink: String?
    /// ID of the attached file. For Google Drive files, this is the Drive file ID.
    let fileId: String?
}

// MARK: - Working Location Properties

/// Properties specific to working location events.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCWorkingLocationProperties: Codable, Sendable {
    /// The type of working location.
    /// Possible values: `"homeOffice"`, `"customLocation"`, `"officeLocation"`.
    let type: String?
    /// If present, specifies that the user is working from home.
    /// This is an empty object in the API.
    let homeOffice: HomeOffice?
    /// If present, specifies that the user is working from a custom location.
    let customLocation: CustomLocation?
    /// If present, specifies that the user is working from an office.
    let officeLocation: OfficeLocation?

    /// Empty marker object for home office working location.
    nonisolated struct HomeOffice: Codable, Sendable {}

    /// A custom working location.
    nonisolated struct CustomLocation: Codable, Sendable {
        /// An optional extra label for additional information.
        let label: String?
    }

    /// An office working location.
    nonisolated struct OfficeLocation: Codable, Sendable {
        /// The building identifier. Corresponds to a building ID in the organization's Resources database.
        let buildingId: String?
        /// The floor identifier.
        let floorId: String?
        /// The floor section identifier.
        let floorSectionId: String?
        /// The desk identifier.
        let deskId: String?
        /// An optional label for additional information.
        let label: String?
    }
}

// MARK: - Out of Office Properties

/// Properties specific to out-of-office events.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCOutOfOfficeProperties: Codable, Sendable {
    /// Whether to decline new and existing meetings.
    /// Possible values: `"declineNone"`, `"declineAllConflictingInvitations"`,
    /// `"declineOnlyNewConflictingInvitations"`.
    let autoDeclineMode: String?
    /// Response message to set if an existing event or new invitation is declined.
    let declineMessage: String?
}

// MARK: - Focus Time Properties

/// Properties specific to focus time events.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCFocusTimeProperties: Codable, Sendable {
    /// Whether to decline new and existing meetings.
    /// Possible values: `"declineNone"`, `"declineAllConflictingInvitations"`,
    /// `"declineOnlyNewConflictingInvitations"`.
    let autoDeclineMode: String?
    /// Response message to set if an existing event or new invitation is declined.
    let declineMessage: String?
    /// The status to mark the user in Chat and related products.
    /// Possible values: `"available"`, `"doNotDisturb"`.
    let chatStatus: String?
}

// MARK: - Birthday Properties

/// Properties specific to birthday events.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCBirthdayProperties: Codable, Sendable {
    /// Resource name of the contact this birthday event is linked to.
    /// Format: `"people/c{contactId}"`.
    let contact: String?
    /// The type of birthday event.
    /// Possible values: `"birthday"`, `"anniversary"`, `"custom"`.
    let type: String?
    /// If the type is `"custom"`, this is the user-provided label for the event type.
    let customTypeName: String?
}
