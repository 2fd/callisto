import Testing
import Foundation
import SwiftData
@testable import calendar

@Suite("GoogleCalendarEvent model")
@MainActor
struct CalendarEventTests {
    @Test func createAndFetchEvent() throws {
        let container = try TestModelContainer.create()
        let context = container.mainContext

        let event = GoogleCalendarEvent(
            compositeId: "cal1/evt1",
            eventId: "evt1",
            accountId: "acc1",
            calendarId: "cal1",
            etag: "\"etag1\"",
            iCalUID: "uid1",
            sequence: 0,
            summary: "Lunch",
            startDate: Date(timeIntervalSince1970: 1_000_000),
            endDate: Date(timeIntervalSince1970: 1_003_600),
            isAllDay: false,
            htmlLink: "https://cal.google.com/evt1",
            status: "confirmed"
        )
        event.location = "Cafe"
        context.insert(event)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<GoogleCalendarEvent>())
        #expect(fetched.count == 1)
        #expect(fetched[0].compositeId == "cal1/evt1")
        #expect(fetched[0].summary == "Lunch")
        #expect(fetched[0].location == "Cafe")
        #expect(fetched[0].accountId == "acc1")
        #expect(fetched[0].calendarId == "cal1")
    }

    @Test func defaultAttendeeCounts() {
        let event = GoogleCalendarEvent(
            compositeId: "c/e",
            eventId: "e",
            accountId: "a",
            calendarId: "c",
            etag: "",
            iCalUID: "u",
            sequence: 0,
            summary: "S",
            startDate: .now,
            endDate: .now,
            isAllDay: false,
            htmlLink: "",
            status: "confirmed"
        )
        #expect(event.totalAttendees == 0)
        #expect(event.acceptedCount == 0)
        #expect(event.selfAttendee == nil)
        #expect(event.selfResponseStatus == nil)
        #expect(event.isDeclined == false)
        #expect(event.isTentativelyAccepted == false)
        #expect(event.allOtherAttendeesDeclined == false)
    }

    @Test func allOtherAttendeesDeclinedWhenEmpty() {
        let event = GoogleCalendarEvent(
            compositeId: "c/e",
            eventId: "e",
            accountId: "a",
            calendarId: "c",
            etag: "",
            iCalUID: "u",
            sequence: 0,
            summary: "S",
            startDate: .now,
            endDate: .now,
            isAllDay: false,
            htmlLink: "",
            status: "confirmed"
        )
        #expect(event.allOtherAttendeesDeclined == false)
    }

    @Test func allOtherAttendeesDeclinedWhenSomeAccepted() {
        let event = GoogleCalendarEvent(
            compositeId: "c/e",
            eventId: "e",
            accountId: "a",
            calendarId: "c",
            etag: "",
            iCalUID: "u",
            sequence: 0,
            summary: "S",
            startDate: .now,
            endDate: .now,
            isAllDay: false,
            htmlLink: "",
            status: "confirmed"
        )
        event.attendees = [
            EventAttendeeMock.make(email: "me@example.com", displayName: "Me", responseStatus: "accepted", isSelf: true),
            EventAttendeeMock.declined(email: "a@example.com", displayName: "A"),
            EventAttendeeMock.accepted(email: "b@example.com", displayName: "B"),
        ]
        #expect(event.allOtherAttendeesDeclined == false)
    }

    @Test func allOtherAttendeesDeclinedWhenAllDeclined() {
        let event = GoogleCalendarEvent(
            compositeId: "c/e",
            eventId: "e",
            accountId: "a",
            calendarId: "c",
            etag: "",
            iCalUID: "u",
            sequence: 0,
            summary: "S",
            startDate: .now,
            endDate: .now,
            isAllDay: false,
            htmlLink: "",
            status: "confirmed"
        )
        event.attendees = [
            EventAttendeeMock.make(email: "me@example.com", displayName: "Me", responseStatus: "accepted", isSelf: true),
            EventAttendeeMock.declined(email: "a@example.com", displayName: "A"),
            EventAttendeeMock.declined(email: "b@example.com", displayName: "B"),
        ]
        #expect(event.allOtherAttendeesDeclined == true)
    }
}
