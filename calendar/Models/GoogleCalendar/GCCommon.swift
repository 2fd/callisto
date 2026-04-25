import Foundation

// MARK: - Event Date/Time

/// Represents an event's start or end time in the Google Calendar API.
///
/// Exactly one of ``dateTime`` or ``date`` is set.
/// Timed events use ``dateTime``; all-day events use ``date``.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCEventDateTime: Codable, Sendable {
    /// RFC 3339 timestamp for timed events (e.g. `"2026-04-05T10:00:00-07:00"`).
    let dateTime: String?
    /// Date string for all-day events (e.g. `"2026-04-05"`).
    let date: String?
    /// IANA time zone name (e.g. `"America/Los_Angeles"`). Optional.
    let timeZone: String?
}

// MARK: - Person (Creator / Organizer)

/// A person associated with an event, used for both `creator` and `organizer` fields.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCPerson: Codable, Sendable {
    /// The person's Profile ID, if available.
    let id: String?
    /// The person's email address, if available.
    let email: String?
    /// The person's name, if available.
    let displayName: String?
    /// Whether this person corresponds to the calendar on which the event appears.
    let `self`: Bool?
}

// MARK: - Reminder

/// A single reminder override on an event or a default reminder on a calendar.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCReminder: Codable, Sendable {
    /// The method used by this reminder. Possible values: `"email"`, `"popup"`.
    let method: String?
    /// Number of minutes before the event start when the reminder should trigger.
    /// Valid values are between 0 and 40320 (4 weeks in minutes).
    let minutes: Int?
}

// MARK: - Conference Data

/// Conference/video call data attached to an event.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/events#resource
nonisolated struct GCConferenceData: Codable, Sendable {
    /// A request to generate a new conference. Used when creating events.
    let createRequest: CreateRequest?
    /// Entry points for joining the conference (video, phone, SIP, etc.).
    let entryPoints: [EntryPoint]?
    /// Information about the conference solution (e.g. Google Meet, Zoom).
    let conferenceSolution: ConferenceSolution?
    /// The ID of the conference. Can be used by developers to keep track of conferences.
    let conferenceId: String?
    /// The signature of the conference data. Generated on server side.
    let signature: String?
    /// Additional notes (such as instructions) to display to the user. HTML-safe.
    let notes: String?

    /// A request to generate a new conference and attach it to the event.
    nonisolated struct CreateRequest: Codable, Sendable {
        /// The client-generated unique ID for this request.
        let requestId: String?
        /// The conference solution type.
        let conferenceSolutionKey: SolutionKey?
        /// The status of the conference create request.
        let status: Status?

        /// The status of a conference create request.
        nonisolated struct Status: Codable, Sendable {
            /// The current status of the conference create request.
            /// Possible values: `"pending"`, `"success"`, `"failure"`.
            let statusCode: String?
        }
    }

    /// A single entry point for joining a conference.
    nonisolated struct EntryPoint: Codable, Sendable {
        /// The type of the conference entry point.
        /// Possible values: `"video"`, `"phone"`, `"sip"`, `"more"`.
        let entryPointType: String?
        /// The URI of the entry point. Maximum length is 1300 characters.
        let uri: String?
        /// The label for the URI (e.g. a formatted phone number).
        let label: String?
        /// The PIN to access the conference (numeric string).
        let pin: String?
        /// The access code to access the conference.
        let accessCode: String?
        /// The meeting code to access the conference (e.g. for Google Meet).
        let meetingCode: String?
        /// The passcode to access the conference.
        let passcode: String?
        /// The password to access the conference.
        let password: String?
    }

    /// Information about the conference solution provider.
    nonisolated struct ConferenceSolution: Codable, Sendable {
        /// The key which uniquely identifies the conference solution.
        let key: SolutionKey?
        /// The user-visible name of the conference solution (e.g. `"Google Meet"`).
        let name: String?
        /// The icon URI for the conference solution.
        let iconUri: String?
    }

    /// Identifies the type of conference solution.
    nonisolated struct SolutionKey: Codable, Sendable {
        /// The conference solution type.
        /// Possible values: `"eventHangout"`, `"eventNamedHangout"`, `"hangoutsMeet"`,
        /// `"addOn"`.
        let type: String?
    }
}

// MARK: - Conference Properties

/// Conferencing properties for a calendar, describing what types of conferences are allowed.
///
/// Shared by both `calendar#calendar` and `calendar#calendarListEntry`.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/calendars#resource
nonisolated struct GCConferenceProperties: Codable, Sendable {
    /// The types of conference solutions supported for this calendar.
    /// Possible values: `"eventHangout"`, `"eventNamedHangout"`, `"hangoutsMeet"`.
    let allowedConferenceSolutionTypes: [String]?
}
