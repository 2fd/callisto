import Foundation

// MARK: - FreeBusy Request

/// A request body for the Google Calendar FreeBusy query endpoint.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/freebusy/query
nonisolated struct GCFreeBusyRequest: Codable, Sendable {
    /// The start of the time range to query (RFC 3339 timestamp). Required.
    let timeMin: String?
    /// The end of the time range to query (RFC 3339 timestamp). Required.
    let timeMax: String?
    /// Time zone used in the response. Optional. The default is UTC.
    let timeZone: String?
    /// Maximal number of calendars for which FreeBusy information is to be provided.
    /// Maximum value is 50. Optional.
    let calendarExpansionMax: Int?
    /// Maximal number of calendar identifiers to be provided for a single group.
    /// Maximum value is 100. Optional. An error is returned for a group with more members.
    let groupExpansionMax: Int?
    /// List of calendars and/or groups to query.
    let items: [Item]?

    /// A single calendar or group identifier for a FreeBusy query.
    nonisolated struct Item: Codable, Sendable {
        /// The identifier of a calendar or a group to query.
        let id: String?
    }
}

// MARK: - FreeBusy Response

/// The response from the Google Calendar FreeBusy query endpoint.
///
/// Reference: https://developers.google.com/calendar/api/v3/reference/freebusy/query
nonisolated struct GCFreeBusyResponse: Codable, Sendable {

    /// Type of the resource. Always `"calendar#freeBusy"`.
    let kind: String
    /// The start of the time range (RFC 3339 timestamp).
    let timeMin: String?
    /// The end of the time range (RFC 3339 timestamp).
    let timeMax: String?
    /// A map of calendar IDs to their free/busy information.
    let calendars: [String: CalendarFreeBusy]?
    /// Expansion of groups. A map of group IDs to their member calendars.
    let groups: [String: GroupInfo]?

    // MARK: - Calendar FreeBusy

    /// Free/busy information for a single calendar.
    nonisolated struct CalendarFreeBusy: Codable, Sendable {
        /// List of time ranges during which the calendar is busy.
        let busy: [TimePeriod]?
        /// Optional errors encountered while fetching this calendar's free/busy info.
        let errors: [FreeBusyError]?
    }

    // MARK: - Time Period

    /// A single busy time period.
    nonisolated struct TimePeriod: Codable, Sendable {
        /// The start of the busy period (RFC 3339 timestamp).
        let start: String?
        /// The end of the busy period (RFC 3339 timestamp).
        let end: String?
    }

    // MARK: - FreeBusy Error

    /// An error encountered while querying free/busy information.
    nonisolated struct FreeBusyError: Codable, Sendable {
        /// Domain or source of the error.
        let domain: String?
        /// The specific reason for the error.
        let reason: String?
    }

    // MARK: - Group Info

    /// Group expansion information showing which calendars belong to a group.
    nonisolated struct GroupInfo: Codable, Sendable {
        /// List of calendar identifiers within this group.
        let calendars: [String]?
        /// Optional errors encountered while expanding this group.
        let errors: [FreeBusyError]?
    }
}
