import Foundation

/// The Google Calendar operations the managers depend on.
///
/// Exists purely as a test seam. Retry, backoff and error classification are
/// only meaningful if they can be exercised against canned 401/403/410/429
/// responses, and that is impossible while the managers construct a concrete
/// `GoogleCalendarAPI()` inline.
///
/// Deliberately narrower than ``GoogleCalendarAPI``: it covers what the sync
/// and mutation paths call, so a fake stays small. Endpoints no caller uses
/// yet (`insert`, `move`, `import`, `quickAdd`, `instances`) remain concrete
/// methods on the client and can be promoted when something calls them.
nonisolated protocol CalendarAPI: Sendable {

    /// Fetches the authenticated user's calendar list.
    func listCalendars(accessToken: String) async throws -> GCCalendarListResponse

    /// Fetches the color palettes for the token's account.
    func listColors(accessToken: String) async throws -> GCColors

    /// Fetches every page of events on a calendar within `[timeMin, timeMax]`.
    ///
    /// `updatedMin` selects the incremental mode; see
    /// ``GoogleCalendarAPI/listAllEvents(calendarId:accessToken:timeMin:timeMax:updatedMin:showDeleted:)``
    /// for the pruning caveat that comes with it.
    func listAllEvents(
        calendarId: String,
        accessToken: String,
        timeMin: Date,
        timeMax: Date,
        updatedMin: Date?,
        showDeleted: Bool
    ) async throws -> [GCEvent]

    /// Fetches a single event by ID.
    func getEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        timeZone: String?
    ) async throws -> GCEvent

    /// Partially updates an event; only the keys present in `body` are changed.
    func patchEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        body: GCEventWrite,
        sendUpdates: GoogleCalendarAPI.SendUpdates,
        conferenceDataVersion: Int?,
        supportsAttachments: Bool?
    ) async throws -> GCEvent

    /// Deletes an event.
    func deleteEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        sendUpdates: GoogleCalendarAPI.SendUpdates
    ) async throws
}

extension CalendarAPI {

    /// Convenience overload matching the common call shape.
    func getEvent(
        calendarId: String,
        eventId: String,
        accessToken: String
    ) async throws -> GCEvent {
        try await getEvent(
            calendarId: calendarId,
            eventId: eventId,
            accessToken: accessToken,
            timeZone: nil
        )
    }

    /// Convenience overload matching the common call shape.
    func patchEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        body: GCEventWrite,
        sendUpdates: GoogleCalendarAPI.SendUpdates
    ) async throws -> GCEvent {
        try await patchEvent(
            calendarId: calendarId,
            eventId: eventId,
            accessToken: accessToken,
            body: body,
            sendUpdates: sendUpdates,
            conferenceDataVersion: nil,
            supportsAttachments: nil
        )
    }
}
