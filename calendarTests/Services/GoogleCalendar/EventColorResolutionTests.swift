import Foundation
import SwiftData
import Testing

@testable import calendar

/// Which color a row is drawn in: the event's own when it has one, the
/// calendar's otherwise.
@MainActor
@Suite("Event color resolution")
struct EventColorResolutionTests {

    private func makeManager() throws -> GoogleCalendarManager {
        let container = try TestModelContainer.create()
        return GoogleCalendarManager(
            accounts: GoogleAccountManager(container: container),
            container: container,
            api: FakeCalendarAPI()
        )
    }

    private func makeEvent(accountId: String = "acc", colorId: String?) -> GoogleCalendarEvent {
        let event = GoogleCalendarEvent(
            compositeId: "cal/evt",
            eventId: "evt",
            accountId: accountId,
            calendarId: "cal",
            etag: "\"e\"",
            iCalUID: "uid",
            sequence: 0,
            summary: "Event",
            startDate: .now,
            endDate: .now.addingTimeInterval(3600),
            isAllDay: false,
            htmlLink: "https://cal.google.com/evt",
            status: "confirmed"
        )
        event.colorId = colorId
        return event
    }

    /// `backgroundColor` carries the legacy value Google resolves the entry to;
    /// `colorId` is what the current color has to be looked up from.
    private func makeCalendar(
        accountId: String = "acc",
        colorId: String? = "14",
        backgroundColor: String = "#9fe1e7"
    ) -> GoogleCalendar {
        let calendar = GoogleCalendar(
            calendarId: "cal",
            accountId: accountId,
            backgroundColor: backgroundColor
        )
        calendar.colorId = colorId
        return calendar
    }

    @Test("An event with no color of its own inherits its calendar's")
    func inheritsCalendarColor() throws {
        let manager = try makeManager()
        let color = manager.color(
            for: makeEvent(colorId: nil),
            in: makeCalendar()
        )
        // Peacock as the product draws it, not the `#9fe1e7` Google resolved
        // the calendar list entry to.
        #expect(color == "#039be5")
    }

    @Test("A calendar with a custom RGB color keeps its own background")
    func customCalendarColorSurvives() throws {
        let manager = try makeManager()
        let color = manager.color(
            for: makeEvent(colorId: nil),
            in: makeCalendar(colorId: nil, backgroundColor: "#123456")
        )
        // No palette ID to resolve, so the entry's own value is the only answer.
        #expect(color == "#123456")
    }

    @Test("An event with a colorId is drawn in that color, not its calendar's")
    func ownColorWins() throws {
        let manager = try makeManager()
        let color = manager.color(
            for: makeEvent(colorId: "11"),
            in: makeCalendar()
        )
        #expect(color == "#d50000")
    }

    @Test("An unresolvable colorId falls back to the calendar rather than to nothing")
    func unknownColorIdFallsBack() throws {
        let manager = try makeManager()
        let color = manager.color(
            for: makeEvent(colorId: "99"),
            in: makeCalendar()
        )
        #expect(color == "#039be5")
    }

    @Test("An account with no fetched palette uses the built-in defaults")
    func unsyncedAccountUsesDefaults() throws {
        let manager = try makeManager()
        #expect(manager.palette(for: "never-synced") == .googleDefaults)
    }
}
