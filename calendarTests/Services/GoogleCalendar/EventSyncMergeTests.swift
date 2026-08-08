import Foundation
import SwiftData
import Testing

@testable import calendar

/// The merge rules that decide what survives a sync.
///
/// The distinction these cover is the one that used to be wrong: a full
/// response is authoritative for the whole window, an incremental one is not,
/// and treating the second like the first empties the calendar.
@MainActor
@Suite("Event sync merge")
struct EventSyncMergeTests {

    private func makeManager() throws -> GoogleCalendarEventManager {
        let container = try TestModelContainer.create()
        return GoogleCalendarEventManager(container: container, api: FakeCalendarAPI())
    }

    private func event(
        id: String,
        etag: String = "v1",
        status: String = EventStatus.confirmed,
        startOffsetHours: Int = 2
    ) -> GCEvent {
        let start = Date.now.addingTimeInterval(Double(startOffsetHours) * 3600)
        let end = start.addingTimeInterval(3600)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let json = """
            {"kind":"calendar#event","etag":"\\"\(etag)\\"","id":"\(id)",
             "status":"\(status)","iCalUID":"\(id)@google.com","sequence":0,
             "eventType":"default","summary":"Event \(id)",
             "start":{"dateTime":"\(formatter.string(from: start))"},
             "end":{"dateTime":"\(formatter.string(from: end))"}}
            """
        return try! JSONDecoder().decode(GCEvent.self, from: Data(json.utf8))
    }

    // MARK: - Full sync

    @Test("A full sync inserts what it returns")
    func fullSyncInserts() throws {
        let manager = try makeManager()

        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "a"), event(id: "b")],
            mode: .full
        )

        #expect(manager.events.count == 2)
    }

    @Test("A full sync deletes what it omits — it is authoritative")
    func fullSyncPrunesByAbsence() throws {
        let manager = try makeManager()
        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "a"), event(id: "b")],
            mode: .full
        )

        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "a")],
            mode: .full
        )

        #expect(manager.events.map(\.eventId) == ["a"])
    }

    // MARK: - Incremental sync

    @Test("An incremental sync never deletes by absence")
    func deltaSyncKeepsAbsentEvents() throws {
        let manager = try makeManager()
        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "a"), event(id: "b"), event(id: "c")],
            mode: .full
        )

        // A delta carrying one changed event must not imply the other two are gone.
        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "b", etag: "v2")],
            mode: .delta(since: .now.addingTimeInterval(-300))
        )

        #expect(manager.events.count == 3)
    }

    @Test("An empty incremental sync leaves the cache untouched")
    func emptyDeltaIsNoop() throws {
        let manager = try makeManager()
        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "a"), event(id: "b")],
            mode: .full
        )

        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [],
            mode: .delta(since: .now.addingTimeInterval(-300))
        )

        #expect(manager.events.count == 2)
    }

    @Test("An incremental sync applies updates it does carry")
    func deltaSyncAppliesUpdates() throws {
        let manager = try makeManager()
        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "a")],
            mode: .full
        )
        let before = manager.events[0].etag

        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "a", etag: "v2")],
            mode: .delta(since: .now.addingTimeInterval(-300))
        )

        #expect(manager.events[0].etag != before)
    }

    @Test("A cancelled tombstone deletes the event in incremental mode")
    func deltaSyncHonorsTombstones() throws {
        let manager = try makeManager()
        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "a"), event(id: "b")],
            mode: .full
        )

        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "a", etag: "v2", status: EventStatus.cancelled)],
            mode: .delta(since: .now.addingTimeInterval(-300))
        )

        #expect(manager.events.map(\.eventId) == ["b"])
    }

    @Test("A tombstone for an event we never had is harmless")
    func tombstoneForUnknownEvent() throws {
        let manager = try makeManager()
        manager.applySync(
            accountId: "acc",
            calendarId: "cal",
            fetched: [event(id: "ghost", status: EventStatus.cancelled)],
            mode: .delta(since: .now.addingTimeInterval(-300))
        )

        #expect(manager.events.isEmpty)
    }

    // MARK: - Scoping

    @Test("A sync for one calendar leaves other calendars alone")
    func syncIsScopedToCalendar() throws {
        let manager = try makeManager()
        manager.applySync(
            accountId: "acc", calendarId: "cal-1", fetched: [event(id: "a")], mode: .full
        )
        manager.applySync(
            accountId: "acc", calendarId: "cal-2", fetched: [event(id: "b")], mode: .full
        )

        // An empty authoritative response for cal-1 clears only cal-1.
        manager.applySync(
            accountId: "acc", calendarId: "cal-1", fetched: [], mode: .full
        )

        #expect(manager.events.map(\.calendarId) == ["cal-2"])
    }
}
