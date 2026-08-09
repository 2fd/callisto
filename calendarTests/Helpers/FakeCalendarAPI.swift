import Foundation

@testable import calendar

/// A scriptable ``CalendarAPI`` for exercising the managers without a network.
///
/// Each endpoint is backed by a queue of outcomes so a test can express a
/// sequence — "fail with 410, then succeed" — which is the shape most of the
/// sync recovery logic is about.
final class FakeCalendarAPI: CalendarAPI, @unchecked Sendable {

    /// One scripted outcome.
    enum Outcome<Value> {
        case success(Value)
        case failure(APIError)
    }

    private let lock = NSLock()

    private var calendarOutcomes: [Outcome<GCCalendarListResponse>] = []
    private var eventOutcomes: [Outcome<[GCEvent]>] = []
    private var colorOutcomes: [Outcome<GCColors>] = []

    // MARK: - Recorded calls

    /// Every `listAllEvents` call, in order.
    private(set) var eventRequests: [EventRequest] = []
    private(set) var calendarRequestCount = 0
    /// Access tokens `listColors` was called with, in order. The palette is
    /// per account, so the token is what tells two accounts apart.
    private(set) var colorRequestTokens: [String] = []

    struct EventRequest: Sendable {
        let calendarId: String
        let timeMin: Date
        let timeMax: Date
        let updatedMin: Date?
        let showDeleted: Bool

        /// Whether this was an incremental request.
        var isDelta: Bool { updatedMin != nil }
    }

    // MARK: - Scripting

    func enqueueCalendars(_ response: GCCalendarListResponse) {
        lock.withLock { calendarOutcomes.append(.success(response)) }
    }

    func enqueueCalendarFailure(_ error: APIError) {
        lock.withLock { calendarOutcomes.append(.failure(error)) }
    }

    func enqueueColors(_ colors: GCColors) {
        lock.withLock { colorOutcomes.append(.success(colors)) }
    }

    func enqueueColorFailure(_ error: APIError) {
        lock.withLock { colorOutcomes.append(.failure(error)) }
    }

    func enqueueEvents(_ events: [GCEvent]) {
        lock.withLock { eventOutcomes.append(.success(events)) }
    }

    func enqueueEventFailure(_ error: APIError) {
        lock.withLock { eventOutcomes.append(.failure(error)) }
    }

    // MARK: - CalendarAPI

    func listCalendars(accessToken: String) async throws -> GCCalendarListResponse {
        try lock.withLock {
            calendarRequestCount += 1
            guard !calendarOutcomes.isEmpty else {
                return GCCalendarListResponse.empty
            }
            switch calendarOutcomes.removeFirst() {
            case .success(let response): return response
            case .failure(let error): throw error
            }
        }
    }

    func listColors(accessToken: String) async throws -> GCColors {
        try lock.withLock {
            colorRequestTokens.append(accessToken)
            guard !colorOutcomes.isEmpty else {
                return GCColors.empty
            }
            switch colorOutcomes.removeFirst() {
            case .success(let colors): return colors
            case .failure(let error): throw error
            }
        }
    }

    func listAllEvents(
        calendarId: String,
        accessToken: String,
        timeMin: Date,
        timeMax: Date,
        updatedMin: Date?,
        showDeleted: Bool
    ) async throws -> [GCEvent] {
        try lock.withLock {
            eventRequests.append(
                EventRequest(
                    calendarId: calendarId,
                    timeMin: timeMin,
                    timeMax: timeMax,
                    updatedMin: updatedMin,
                    showDeleted: showDeleted
                )
            )
            guard !eventOutcomes.isEmpty else { return [] }
            switch eventOutcomes.removeFirst() {
            case .success(let events): return events
            case .failure(let error): throw error
            }
        }
    }

    func getEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        timeZone: String?
    ) async throws -> GCEvent {
        throw APIError.notFound(message: "not scripted")
    }

    func patchEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        body: GCEventWrite,
        sendUpdates: GoogleCalendarAPI.SendUpdates,
        conferenceDataVersion: Int?,
        supportsAttachments: Bool?
    ) async throws -> GCEvent {
        throw APIError.notFound(message: "not scripted")
    }

    func deleteEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        sendUpdates: GoogleCalendarAPI.SendUpdates
    ) async throws {
        throw APIError.notFound(message: "not scripted")
    }
}

extension GCColors {
    static var empty: GCColors {
        GCColors(
            kind: "calendar#colors",
            updated: "2026-01-01T00:00:00.000Z",
            calendar: [:],
            event: [:]
        )
    }

    /// A palette built from `colorId: background` pairs.
    static func make(
        event: [String: String] = [:],
        calendar: [String: String] = [:]
    ) -> GCColors {
        func definitions(_ pairs: [String: String]) -> [String: GCColorDefinition] {
            pairs.mapValues { GCColorDefinition(background: $0, foreground: "#1d1d1d") }
        }
        return GCColors(
            kind: "calendar#colors",
            updated: "2026-01-01T00:00:00.000Z",
            calendar: definitions(calendar),
            event: definitions(event)
        )
    }
}

extension GCCalendarListResponse {
    static var empty: GCCalendarListResponse {
        GCCalendarListResponse(
            kind: "calendar#calendarList",
            etag: "\"etag\"",
            nextPageToken: nil,
            nextSyncToken: nil,
            items: []
        )
    }
}
