import Foundation
import Testing

@testable import calendar

/// Exercises the real client against canned responses: the retry loop, the
/// paging loop, and which failures are allowed to reach the caller.
///
/// Serialized because ``StubURLProtocol`` holds its script in shared state.
@Suite("GoogleCalendarAPI", .serialized)
struct GoogleCalendarAPITests {

    private static let quota403 = """
        {"error":{"code":403,"message":"Rate Limit Exceeded","errors":[
          {"domain":"usageLimits","reason":"rateLimitExceeded"}]}}
        """

    private static let scope403 = """
        {"error":{"code":403,"message":"Insufficient Permission","errors":[
          {"domain":"global","reason":"insufficientPermissions"}]}}
        """

    private static func eventsPage(ids: [String], nextPageToken: String? = nil) -> String {
        let items = ids.map { id in
            """
            {"kind":"calendar#event","etag":"\\"\(id)-etag\\"","id":"\(id)",
             "status":"confirmed","iCalUID":"\(id)@google.com","sequence":0,
             "eventType":"default",
             "start":{"dateTime":"2026-08-10T10:00:00Z"},
             "end":{"dateTime":"2026-08-10T11:00:00Z"}}
            """
        }.joined(separator: ",")
        let token = nextPageToken.map { "\"nextPageToken\":\"\($0)\"," } ?? ""
        return """
            {"kind":"calendar#events","etag":"\\"list\\"",\(token)"items":[\(items)]}
            """
    }

    private let window = (min: Date(timeIntervalSince1970: 0), max: Date(timeIntervalSince1970: 86_400))

    // MARK: - Retry

    @Test("A throttled request is retried and can then succeed")
    func retriesThrottleThenSucceeds() async throws {
        StubURLProtocol.script([
            .json(403, Self.quota403),
            .json(403, Self.quota403),
            .json(200, Self.eventsPage(ids: ["a"])),
        ])
        let api = StubURLProtocol.makeAPI()

        let events = try await api.listAllEvents(
            calendarId: "cal",
            accessToken: "token",
            timeMin: window.min,
            timeMax: window.max,
            updatedMin: nil,
            showDeleted: false
        )

        #expect(events.count == 1)
        #expect(StubURLProtocol.requestCount == 3)
    }

    @Test("Retries are bounded and the last error is surfaced")
    func retriesAreBounded() async {
        StubURLProtocol.script([.json(403, Self.quota403)])
        let api = StubURLProtocol.makeAPI(maxAttempts: 3)

        await #expect(throws: APIError.self) {
            try await api.listCalendars(accessToken: "token")
        }
        #expect(StubURLProtocol.requestCount == 3)
    }

    @Test("A 500 is retried")
    func retriesServerError() async throws {
        StubURLProtocol.script([
            .json(500, #"{"error":{"code":500,"errors":[{"reason":"backendError"}]}}"#),
            .json(200, #"{"kind":"calendar#calendarList","etag":"\"e\"","items":[]}"#),
        ])
        let api = StubURLProtocol.makeAPI()

        _ = try await api.listCalendars(accessToken: "token")
        #expect(StubURLProtocol.requestCount == 2)
    }

    @Test("A scope failure is never retried — repetition cannot help")
    func doesNotRetryScopeFailure() async {
        StubURLProtocol.script([.json(403, Self.scope403)])
        let api = StubURLProtocol.makeAPI()

        await #expect(throws: APIError.self) {
            try await api.listCalendars(accessToken: "token")
        }
        #expect(StubURLProtocol.requestCount == 1)
    }

    @Test("A 401 is not retried here — the token layer owns that recovery")
    func doesNotRetryUnauthorized() async {
        StubURLProtocol.script([
            .json(401, #"{"error":{"code":401,"errors":[{"reason":"authError"}]}}"#)
        ])
        let api = StubURLProtocol.makeAPI()

        await #expect(throws: APIError.self) {
            try await api.listCalendars(accessToken: "stale")
        }
        #expect(StubURLProtocol.requestCount == 1)
    }

    @Test("A 400 is not retried")
    func doesNotRetryBadRequest() async {
        StubURLProtocol.script([
            .json(400, #"{"error":{"code":400,"errors":[{"reason":"timeRangeEmpty"}]}}"#)
        ])
        let api = StubURLProtocol.makeAPI()

        await #expect(throws: APIError.self) {
            try await api.listCalendars(accessToken: "token")
        }
        #expect(StubURLProtocol.requestCount == 1)
    }

    // MARK: - Paging

    @Test("Every page is followed, not just the first")
    func followsPagination() async throws {
        StubURLProtocol.script([
            .json(200, Self.eventsPage(ids: ["a", "b"], nextPageToken: "p2")),
            .json(200, Self.eventsPage(ids: ["c"], nextPageToken: "p3")),
            .json(200, Self.eventsPage(ids: ["d"])),
        ])
        let api = StubURLProtocol.makeAPI()

        let events = try await api.listAllEvents(
            calendarId: "cal",
            accessToken: "token",
            timeMin: window.min,
            timeMax: window.max,
            updatedMin: nil,
            showDeleted: false
        )

        #expect(events.map(\.id) == ["a", "b", "c", "d"])
        #expect(StubURLProtocol.requestCount == 3)
    }

    @Test("The continuation token is sent on subsequent pages")
    func sendsPageToken() async throws {
        StubURLProtocol.script([
            .json(200, Self.eventsPage(ids: ["a"], nextPageToken: "TOKEN-2")),
            .json(200, Self.eventsPage(ids: ["b"])),
        ])
        let api = StubURLProtocol.makeAPI()

        _ = try await api.listAllEvents(
            calendarId: "cal",
            accessToken: "token",
            timeMin: window.min,
            timeMax: window.max,
            updatedMin: nil,
            showDeleted: false
        )

        let second = StubURLProtocol.requestedURLs[1].absoluteString
        #expect(second.contains("pageToken=TOKEN-2"))
    }

    @Test("Colors are read from the account-level colors endpoint")
    func listColorsRequestShape() async throws {
        StubURLProtocol.script([
            .json(
                200,
                """
                {"kind":"calendar#colors","updated":"2012-02-14T00:00:00.000Z",
                 "calendar":{},"event":{"11":{"background":"#dc2127","foreground":"#1d1d1d"}}}
                """
            )
        ])
        let api = StubURLProtocol.makeAPI()

        let colors = try await api.listColors(accessToken: "token")

        #expect(colors.event["11"]?.background == "#dc2127")
        #expect(StubURLProtocol.requestedURLs[0].path == "/calendar/v3/colors")
    }

    // MARK: - Query shape

    @Test("Incremental requests send updatedMin and ask for tombstones")
    func deltaRequestShape() async throws {
        StubURLProtocol.script([.json(200, Self.eventsPage(ids: []))])
        let api = StubURLProtocol.makeAPI()

        _ = try await api.listAllEvents(
            calendarId: "cal",
            accessToken: "token",
            timeMin: window.min,
            timeMax: window.max,
            updatedMin: Date(timeIntervalSince1970: 1000),
            showDeleted: true
        )

        let url = StubURLProtocol.requestedURLs[0].absoluteString
        #expect(url.contains("updatedMin="))
        #expect(url.contains("showDeleted=true"))
    }

    @Test("Full requests send no updatedMin")
    func fullRequestShape() async throws {
        StubURLProtocol.script([.json(200, Self.eventsPage(ids: []))])
        let api = StubURLProtocol.makeAPI()

        _ = try await api.listAllEvents(
            calendarId: "cal",
            accessToken: "token",
            timeMin: window.min,
            timeMax: window.max,
            updatedMin: nil,
            showDeleted: false
        )

        let url = StubURLProtocol.requestedURLs[0].absoluteString
        #expect(!url.contains("updatedMin="))
        #expect(url.contains("singleEvents=true"))
        // The bounds are what stop an infinitely recurring event expanding
        // without limit under singleEvents.
        #expect(url.contains("timeMin="))
        #expect(url.contains("timeMax="))
    }

    @Test("A calendar ID with slashes is escaped into the path")
    func escapesCalendarId() async throws {
        StubURLProtocol.script([.json(200, Self.eventsPage(ids: []))])
        let api = StubURLProtocol.makeAPI()

        _ = try await api.listAllEvents(
            calendarId: "user@example.com",
            accessToken: "token",
            timeMin: window.min,
            timeMax: window.max,
            updatedMin: nil,
            showDeleted: false
        )

        #expect(
            StubURLProtocol.requestedURLs[0].absoluteString
                .contains("/calendars/user@example.com/events")
        )
    }
}
