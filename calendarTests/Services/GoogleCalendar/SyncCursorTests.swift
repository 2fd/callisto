import Foundation
import SwiftData
import Testing

@testable import calendar

/// When a calendar may be read incrementally, and when it must be re-read whole.
@MainActor
@Suite("Sync cursor")
struct SyncCursorTests {

    private struct Fixture {
        let manager: GoogleCalendarManager
        let calendar: GoogleCalendar
        let today: Date
    }

    private func makeFixture() throws -> Fixture {
        let container = try TestModelContainer.create()
        let context = ModelContext(container)
        context.insert(GoogleCalendar(calendarId: "cal", accountId: "acc"))
        try context.save()

        // The manager mirrors its rows into memory at init, so it is built after
        // the fixture row exists.
        let manager = GoogleCalendarManager(
            accounts: GoogleAccountManager(container: container),
            container: container,
            api: FakeCalendarAPI()
        )
        return Fixture(
            manager: manager,
            calendar: manager.get(calendarId: "cal")!,
            today: Calendar.current.startOfDay(for: .now)
        )
    }

    @Test("A calendar with no cursor is read in full")
    func firstSyncIsFull() throws {
        let f = try makeFixture()
        #expect(f.manager.syncMode(for: "cal", windowStart: f.today) == .full)
    }

    @Test("An unknown calendar is read in full")
    func unknownCalendarIsFull() throws {
        let f = try makeFixture()
        #expect(f.manager.syncMode(for: "missing", windowStart: f.today) == .full)
    }

    @Test("A fresh cursor for the current window allows an incremental read")
    func freshCursorIsDelta() throws {
        let f = try makeFixture()
        f.manager.markEventsSynced(
            calendarId: "cal",
            mode: .full,
            windowStart: f.today,
            startedAt: .now
        )

        let mode = f.manager.syncMode(for: "cal", windowStart: f.today)
        guard case .delta = mode else {
            Issue.record("expected .delta, got \(mode)")
            return
        }
    }

    @Test("The incremental cursor is backdated to absorb clock skew")
    func deltaCursorOverlaps() throws {
        let f = try makeFixture()
        let startedAt = Date.now
        f.manager.markEventsSynced(
            calendarId: "cal", mode: .full, windowStart: f.today, startedAt: startedAt
        )

        guard case .delta(let since) = f.manager.syncMode(for: "cal", windowStart: f.today)
        else {
            Issue.record("expected .delta")
            return
        }
        #expect(since < startedAt)
        #expect(startedAt.timeIntervalSince(since) == Constants.deltaSyncOverlap)
    }

    @Test("When the day rolls over the window moves and a full read is required")
    func windowRollForcesFull() throws {
        let f = try makeFixture()
        f.manager.markEventsSynced(
            calendarId: "cal", mode: .full, windowStart: f.today, startedAt: .now
        )

        // Events newly inside tomorrow's window were not modified, so no
        // `updatedMin` query would ever return them.
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: f.today)!
        #expect(f.manager.syncMode(for: "cal", windowStart: tomorrow) == .full)
    }

    @Test("A stale full sync forces another full read")
    func staleFullSyncForcesFull() throws {
        let f = try makeFixture()
        f.manager.markEventsSynced(
            calendarId: "cal", mode: .full, windowStart: f.today, startedAt: .now
        )
        f.calendar.lastFullSyncAt = .now.addingTimeInterval(
            -Constants.fullSyncInterval - 60
        )

        #expect(f.manager.syncMode(for: "cal", windowStart: f.today) == .full)
    }

    @Test("An incremental read does not refresh the full-sync clock")
    func deltaDoesNotResetFullSyncClock() throws {
        let f = try makeFixture()
        f.manager.markEventsSynced(
            calendarId: "cal", mode: .full, windowStart: f.today, startedAt: .now
        )
        let fullSyncAt = f.calendar.lastFullSyncAt

        f.manager.markEventsSynced(
            calendarId: "cal",
            mode: .delta(since: .now),
            windowStart: f.today,
            startedAt: .now
        )

        #expect(f.calendar.lastFullSyncAt == fullSyncAt)
    }

    @Test("Invalidating the cursor forces a full read")
    func invalidationForcesFull() throws {
        let f = try makeFixture()
        f.manager.markEventsSynced(
            calendarId: "cal", mode: .full, windowStart: f.today, startedAt: .now
        )

        f.manager.invalidateSyncCursor(calendarId: "cal")

        #expect(f.manager.syncMode(for: "cal", windowStart: f.today) == .full)
        #expect(f.calendar.lastDeltaSyncAt == nil)
    }
}

/// Account health must track the connection without ever standing in for the
/// grant, and without costing the user their cached data.
@MainActor
@Suite("Account health")
struct AccountHealthTests {

    private func makeManager() throws -> (GoogleAccountManager, GoogleAccount) {
        let container = try TestModelContainer.create()
        let context = ModelContext(container)
        context.insert(
            GoogleAccount(accountId: "acc", email: "a@example.com", displayName: "A")
        )
        try context.save()
        let manager = GoogleAccountManager(container: container)
        return (manager, manager.get("acc")!)
    }

    @Test("Throttling suspends the account without touching its permissions")
    func throttlingDoesNotRevoke() throws {
        let (manager, account) = try makeManager()

        manager.recordSyncFailure(
            "acc",
            error: APIError.throttled(reason: "rateLimitExceeded", retryAfter: 30)
        )

        #expect(account.syncState == .throttled)
        #expect(account.canRead)
        #expect(account.isThrottled)
        #expect(!account.isSyncable)
    }

    @Test("A throttled account becomes syncable again once the window passes")
    func throttleExpires() throws {
        let (manager, account) = try makeManager()
        manager.recordSyncFailure(
            "acc",
            error: APIError.throttled(reason: "rateLimitExceeded", retryAfter: 30)
        )

        account.throttledUntil = .now.addingTimeInterval(-1)

        #expect(!account.isThrottled)
        #expect(account.isSyncable)
    }

    @Test("A scope failure is the only thing that revokes the grant")
    func scopeDenialRevokes() throws {
        let (manager, account) = try makeManager()

        manager.recordSyncFailure(
            "acc",
            error: APIError.scopeDenied(reason: "insufficientPermissions", message: "")
        )

        #expect(account.syncState == .needsReauth)
        #expect(!account.canRead)
    }

    @Test("A server error never revokes the grant")
    func serverErrorDoesNotRevoke() throws {
        let (manager, account) = try makeManager()

        manager.recordSyncFailure(
            "acc",
            error: APIError.server(statusCode: 503, message: "unavailable")
        )

        #expect(account.syncState == .failing)
        #expect(account.canRead)
    }

    @Test("An offline failure never revokes the grant")
    func transportErrorDoesNotRevoke() throws {
        let (manager, account) = try makeManager()

        manager.recordSyncFailure("acc", error: APIError.transport("offline"))

        #expect(account.syncState == .failing)
        #expect(account.canRead)
    }

    @Test("A request-scoped refusal leaves the account healthy")
    func requestScopedFailureIsNotAccountHealth() throws {
        let (manager, account) = try makeManager()

        manager.recordSyncFailure(
            "acc",
            error: APIError.forbidden(reason: "forbiddenForNonOrganizer", message: "")
        )

        #expect(account.syncState == .ok)
        #expect(account.consecutiveFailures == 0)
    }

    @Test("A refresh token rejected as invalid_grant needs re-authorization")
    func invalidGrantNeedsReauth() throws {
        let (manager, account) = try makeManager()

        manager.recordSyncFailure(
            "acc",
            error: AuthError.refreshFailed(#"{"error":"invalid_grant"}"#)
        )

        #expect(account.syncState == .needsReauth)
    }

    @Test("A refresh that failed for any other reason is transient")
    func otherRefreshFailureIsTransient() throws {
        let (manager, account) = try makeManager()

        manager.recordSyncFailure(
            "acc",
            error: AuthError.refreshFailed("connection reset")
        )

        #expect(account.syncState == .failing)
        #expect(account.canRead)
    }

    @Test("Success clears the failure state")
    func successClearsFailures() throws {
        let (manager, account) = try makeManager()
        manager.recordSyncFailure("acc", error: APIError.transport("offline"))
        manager.recordSyncFailure("acc", error: APIError.transport("offline"))

        manager.recordSyncSuccess("acc")

        #expect(account.syncState == .ok)
        #expect(account.consecutiveFailures == 0)
        #expect(account.throttledUntil == nil)
        #expect(account.lastSyncError == nil)
    }

    @Test("Consecutive failures accumulate")
    func failuresAccumulate() throws {
        let (manager, account) = try makeManager()

        manager.recordSyncFailure("acc", error: APIError.transport("offline"))
        manager.recordSyncFailure("acc", error: APIError.transport("offline"))

        #expect(account.consecutiveFailures == 2)
        #expect(account.lastSyncError != nil)
    }
}
