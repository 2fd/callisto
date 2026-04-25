import Testing
import Foundation
import SwiftData
@testable import calendar

@Suite("GoogleCalendar model")
@MainActor
struct GoogleCalendarTests {
    @Test func createAndFetchCalendar() throws {
        let container = try TestModelContainer.create()
        let context = container.mainContext

        let cal = GoogleCalendar(
            calendarId: "work@group.v.calendar.google.com",
            accountId: "acc1",
            summary: "Work",
            backgroundColor: "#4285F4"
        )
        context.insert(cal)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<GoogleCalendar>())
        #expect(fetched.count == 1)
        #expect(fetched[0].calendarId == "work@group.v.calendar.google.com")
        #expect(fetched[0].summary == "Work")
        #expect(fetched[0].accountId == "acc1")
    }

    @Test func defaultIsVisibleTrue() {
        let cal = GoogleCalendar(calendarId: "x", accountId: "acc", summary: "X")
        #expect(cal.isVisible == true)
    }
}
