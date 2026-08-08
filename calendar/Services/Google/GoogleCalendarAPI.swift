import Foundation
import os

/// Thin HTTP client for the Google Calendar API v3.
///
/// Stateless and ``Sendable`` — callers supply an access token per request.
/// Non-2xx responses are surfaced as ``APIError``.
///
/// Owns the one retry policy in the app for failures that are purely about the
/// transport: throttling, server errors, and dropped connections. Authentication
/// retries deliberately live one layer up, in
/// ``GoogleAccountManager/withToken(for:_:)``, because recovering from a 401
/// requires the refresh token this type has no business knowing about.
nonisolated struct GoogleCalendarAPI: CalendarAPI {
    private static let base = "https://www.googleapis.com/calendar/v3"

    private let session: URLSession
    private let retryPolicy: RetryPolicy

    /// - Parameters:
    ///   - session: Defaults to ``defaultSession``; overridden in tests to
    ///     serve canned responses.
    ///   - retryPolicy: Defaults to ``RetryPolicy/standard``.
    init(
        session: URLSession = GoogleCalendarAPI.defaultSession,
        retryPolicy: RetryPolicy = .standard
    ) {
        self.session = session
        self.retryPolicy = retryPolicy
    }

    /// Session shared by every request.
    ///
    /// `waitsForConnectivity` matters more here than in a typical client: the
    /// app syncs immediately on wake from sleep, when the network interface is
    /// often not up yet, and the default behavior is to fail instantly.
    /// Google requires the literal string `gzip` in the User-Agent — not just
    /// `Accept-Encoding` — before it will compress a response.
    ///
    /// Reference: https://developers.google.com/workspace/calendar/api/guides/performance
    static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.httpAdditionalHeaders = [
            "Accept-Encoding": "gzip",
            "User-Agent": "\(AppInfo.displayName)/\(AppInfo.version) (gzip)",
        ]
        return URLSession(configuration: config)
    }()

    // MARK: - Calendar list

    /// Fetches the authenticated user's calendar list.
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/calendarList/list
    func listCalendars(accessToken: String) async throws -> GCCalendarListResponse {
        try await request(
            method: "GET",
            path: "/users/me/calendarList",
            accessToken: accessToken
        )
    }

    // MARK: - Events (read)

    /// Maximum page size the API accepts. The default is 250, so asking for the
    /// ceiling turns a busy month into one round trip instead of ten.
    ///
    /// Reference: https://developers.google.com/workspace/calendar/api/v3/reference/events/list
    static let maxPageSize = 2500

    /// Fetches one page of events on a single calendar within `[timeMin, timeMax]`.
    ///
    /// `singleEvents=true` expands recurring series into individual instances;
    /// `orderBy=startTime` is only valid in that mode. The time bounds are also
    /// what keeps an infinitely recurring event from expanding without limit.
    ///
    /// - Parameters:
    ///   - updatedMin: When set, returns only events modified since this time —
    ///     the incremental mode. Google always includes entries deleted since
    ///     this time regardless of `showDeleted`, so absence no longer implies
    ///     deletion in the response and callers must not prune by absence.
    ///   - pageToken: Continuation token from a previous page.
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/list
    func listEvents(
        calendarId: String,
        accessToken: String,
        timeMin: Date,
        timeMax: Date,
        updatedMin: Date? = nil,
        showDeleted: Bool = false,
        pageToken: String? = nil
    ) async throws -> GCEventsListResponse {
        var query = [
            URLQueryItem(name: "timeMin", value: Self.iso8601.string(from: timeMin)),
            URLQueryItem(name: "timeMax", value: Self.iso8601.string(from: timeMax)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: String(Self.maxPageSize)),
            URLQueryItem(name: "showDeleted", value: showDeleted ? "true" : "false"),
        ]
        if let updatedMin {
            query.append(
                URLQueryItem(name: "updatedMin", value: Self.iso8601.string(from: updatedMin))
            )
        }
        if let pageToken {
            query.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        return try await request(
            method: "GET",
            path: eventsPath(calendarId),
            query: query,
            accessToken: accessToken
        )
    }

    /// Fetches every page of events for a calendar, following `nextPageToken`.
    ///
    /// A single page is not the whole answer: the API caps a page well below a
    /// busy calendar's month and signals the remainder with `nextPageToken`.
    /// Ignoring it silently truncates the result.
    func listAllEvents(
        calendarId: String,
        accessToken: String,
        timeMin: Date,
        timeMax: Date,
        updatedMin: Date? = nil,
        showDeleted: Bool = false
    ) async throws -> [GCEvent] {
        var events: [GCEvent] = []
        var pageToken: String?
        var pages = 0

        repeat {
            let page = try await listEvents(
                calendarId: calendarId,
                accessToken: accessToken,
                timeMin: timeMin,
                timeMax: timeMax,
                updatedMin: updatedMin,
                showDeleted: showDeleted,
                pageToken: pageToken
            )
            events.append(contentsOf: page.items)
            pageToken = page.nextPageToken
            pages += 1

            // A cursor that never terminates would loop forever; bound it and
            // say so rather than spinning.
            if pages >= Self.maxPages, pageToken != nil {
                await Logger.shared.error(
                    "Stopped paging \(calendarId, privacy: .public) at \(pages, privacy: .public) pages with more results pending"
                )
                break
            }
        } while pageToken != nil

        return events
    }

    /// Safety bound on pagination. At ``maxPageSize`` per page this is far more
    /// than a month of any real calendar.
    private static let maxPages = 20

    /// Fetches a single event by ID.
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/get
    func getEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        timeZone: String? = nil
    ) async throws -> GCEvent {
        var query: [URLQueryItem] = []
        if let timeZone {
            query.append(URLQueryItem(name: "timeZone", value: timeZone))
        }
        return try await request(
            method: "GET",
            path: eventPath(calendarId, eventId),
            query: query,
            accessToken: accessToken
        )
    }

    /// Lists the instances of a recurring event.
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/instances
    func listEventInstances(
        calendarId: String,
        eventId: String,
        accessToken: String,
        timeMin: Date? = nil,
        timeMax: Date? = nil,
        maxResults: Int? = nil,
        pageToken: String? = nil,
        timeZone: String? = nil
    ) async throws -> GCEventsListResponse {
        var query: [URLQueryItem] = []
        if let timeMin {
            query.append(URLQueryItem(name: "timeMin", value: Self.iso8601.string(from: timeMin)))
        }
        if let timeMax {
            query.append(URLQueryItem(name: "timeMax", value: Self.iso8601.string(from: timeMax)))
        }
        if let maxResults {
            query.append(URLQueryItem(name: "maxResults", value: String(maxResults)))
        }
        if let pageToken {
            query.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        if let timeZone {
            query.append(URLQueryItem(name: "timeZone", value: timeZone))
        }
        return try await request(
            method: "GET",
            path: eventPath(calendarId, eventId) + "/instances",
            query: query,
            accessToken: accessToken
        )
    }

    // MARK: - Events (write)

    /// Creates a new event.
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/insert
    func insertEvent(
        calendarId: String,
        accessToken: String,
        body: GCEventWrite,
        sendUpdates: SendUpdates = .all,
        conferenceDataVersion: Int? = nil,
        supportsAttachments: Bool? = nil
    ) async throws -> GCEvent {
        try await request(
            method: "POST",
            path: eventsPath(calendarId),
            query: writeQuery(
                sendUpdates: sendUpdates,
                conferenceDataVersion: conferenceDataVersion,
                supportsAttachments: supportsAttachments
            ),
            body: body,
            accessToken: accessToken
        )
    }

    /// Replaces an event with a full representation (all writable fields are overwritten).
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/update
    func updateEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        body: GCEventWrite,
        sendUpdates: SendUpdates = .all,
        conferenceDataVersion: Int? = nil,
        supportsAttachments: Bool? = nil
    ) async throws -> GCEvent {
        try await request(
            method: "PUT",
            path: eventPath(calendarId, eventId),
            query: writeQuery(
                sendUpdates: sendUpdates,
                conferenceDataVersion: conferenceDataVersion,
                supportsAttachments: supportsAttachments
            ),
            body: body,
            accessToken: accessToken
        )
    }

    /// Partially updates an event; only the keys present in `body` are changed.
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/patch
    func patchEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        body: GCEventWrite,
        sendUpdates: SendUpdates = .all,
        conferenceDataVersion: Int? = nil,
        supportsAttachments: Bool? = nil
    ) async throws -> GCEvent {
        try await request(
            method: "PATCH",
            path: eventPath(calendarId, eventId),
            query: writeQuery(
                sendUpdates: sendUpdates,
                conferenceDataVersion: conferenceDataVersion,
                supportsAttachments: supportsAttachments
            ),
            body: body,
            accessToken: accessToken
        )
    }

    /// Deletes an event.
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/delete
    func deleteEvent(
        calendarId: String,
        eventId: String,
        accessToken: String,
        sendUpdates: SendUpdates = .all
    ) async throws {
        try await requestVoid(
            method: "DELETE",
            path: eventPath(calendarId, eventId),
            query: [URLQueryItem(name: "sendUpdates", value: sendUpdates.rawValue)],
            accessToken: accessToken
        )
    }

    /// Moves an event to a different calendar (same organizer required).
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/move
    func moveEvent(
        calendarId: String,
        eventId: String,
        destination: String,
        accessToken: String,
        sendUpdates: SendUpdates = .all
    ) async throws -> GCEvent {
        try await request(
            method: "POST",
            path: eventPath(calendarId, eventId) + "/move",
            query: [
                URLQueryItem(name: "destination", value: destination),
                URLQueryItem(name: "sendUpdates", value: sendUpdates.rawValue),
            ],
            accessToken: accessToken
        )
    }

    /// Imports an externally-created event (preserving its iCalUID and organizer).
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/import
    func importEvent(
        calendarId: String,
        accessToken: String,
        body: GCEventWrite,
        conferenceDataVersion: Int? = nil,
        supportsAttachments: Bool? = nil
    ) async throws -> GCEvent {
        var query: [URLQueryItem] = []
        if let conferenceDataVersion {
            query.append(URLQueryItem(name: "conferenceDataVersion", value: String(conferenceDataVersion)))
        }
        if let supportsAttachments {
            query.append(URLQueryItem(name: "supportsAttachments", value: supportsAttachments ? "true" : "false"))
        }
        return try await request(
            method: "POST",
            path: eventsPath(calendarId) + "/import",
            query: query,
            body: body,
            accessToken: accessToken
        )
    }

    /// Creates an event from a free-form natural-language string.
    ///
    /// Reference: https://developers.google.com/calendar/api/v3/reference/events/quickAdd
    func quickAddEvent(
        calendarId: String,
        accessToken: String,
        text: String,
        sendUpdates: SendUpdates = .all
    ) async throws -> GCEvent {
        try await request(
            method: "POST",
            path: eventsPath(calendarId) + "/quickAdd",
            query: [
                URLQueryItem(name: "text", value: text),
                URLQueryItem(name: "sendUpdates", value: sendUpdates.rawValue),
            ],
            accessToken: accessToken
        )
    }

    // MARK: - Types

    /// Notification policy for write operations.
    enum SendUpdates: String, Sendable {
        /// Notify all guests.
        case all
        /// Notify only external guests (non-Google-Workspace attendees).
        case externalOnly
        /// Do not send any notifications.
        case none
    }

    // MARK: - Private helpers

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func escape(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? s
    }

    private func eventsPath(_ calendarId: String) -> String {
        "/calendars/\(escape(calendarId))/events"
    }

    private func eventPath(_ calendarId: String, _ eventId: String) -> String {
        "/calendars/\(escape(calendarId))/events/\(escape(eventId))"
    }

    private func writeQuery(
        sendUpdates: SendUpdates,
        conferenceDataVersion: Int?,
        supportsAttachments: Bool?
    ) -> [URLQueryItem] {
        var query = [URLQueryItem(name: "sendUpdates", value: sendUpdates.rawValue)]
        if let conferenceDataVersion {
            query.append(URLQueryItem(name: "conferenceDataVersion", value: String(conferenceDataVersion)))
        }
        if let supportsAttachments {
            query.append(URLQueryItem(name: "supportsAttachments", value: supportsAttachments ? "true" : "false"))
        }
        return query
    }

    // Decodable response, with JSON body.
    private func request<T: Decodable, B: Encodable>(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: B,
        accessToken: String
    ) async throws -> T {
        let data = try JSONEncoder().encode(body)
        let (responseData, _) = try await perform(
            method: method,
            path: path,
            query: query,
            bodyData: data,
            accessToken: accessToken
        )
        return try JSONDecoder().decode(T.self, from: responseData)
    }

    // Decodable response, no body.
    private func request<T: Decodable>(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        accessToken: String
    ) async throws -> T {
        let (responseData, _) = try await perform(
            method: method,
            path: path,
            query: query,
            bodyData: nil,
            accessToken: accessToken
        )
        return try JSONDecoder().decode(T.self, from: responseData)
    }

    // No response body expected (e.g. DELETE).
    private func requestVoid(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        accessToken: String
    ) async throws {
        _ = try await perform(
            method: method,
            path: path,
            query: query,
            bodyData: nil,
            accessToken: accessToken
        )
    }

    /// Issues the request, retrying the failures Google documents as transient.
    ///
    /// Retries only `.throttled`, `.server`, `.transport` and `.notFound` — the
    /// rows of Google's error table whose prescribed action is backoff. A 400,
    /// a scope failure or a dead sync cursor will never succeed on repetition
    /// and are surfaced immediately.
    private func perform(
        method: String,
        path: String,
        query: [URLQueryItem],
        bodyData: Data?,
        accessToken: String
    ) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            attempt += 1
            do {
                return try await send(
                    method: method,
                    path: path,
                    query: query,
                    bodyData: bodyData,
                    accessToken: accessToken
                )
            } catch let error as APIError where error.isRetryable {
                guard attempt < retryPolicy.maxAttempts else {
                    await Logger.shared.error(
                        "GoogleCalendarAPI \(method, privacy: .public) \(path, privacy: .public) giving up after \(attempt, privacy: .public) attempts: \(error.localizedDescription, privacy: .public)"
                    )
                    throw error
                }
                let delay = retryPolicy.delay(attempt, error.retryAfter)
                await Logger.shared.debug(
                    "GoogleCalendarAPI \(method, privacy: .public) \(path, privacy: .public) retry \(attempt, privacy: .public) in \(delay, privacy: .public)s"
                )
                try await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func send(
        method: String,
        path: String,
        query: [URLQueryItem],
        bodyData: Data?,
        accessToken: String
    ) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents(string: Self.base + path)!
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.invalidRequest(
                reason: "malformedURL",
                message: "Invalid URL for \(path)"
            )
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let bodyData {
            req.httpBody = bodyData
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError.from(transportError: error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("No HTTP response for \(path)")
        }
        if !(200...299).contains(http.statusCode) {
            let error = APIError.classify(
                statusCode: http.statusCode,
                retryAfterHeader: http.value(forHTTPHeaderField: "Retry-After"),
                body: data
            )
            await Logger.shared.error(
                "GoogleCalendarAPI \(method, privacy: .public) \(path, privacy: .public) HTTP \(http.statusCode): \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
        return (data, http)
    }
}
