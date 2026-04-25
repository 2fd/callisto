import Testing
import Foundation
@testable import calendar

@Suite("DateParsing")
struct DateParsingTests {
    @Test func rfc3339WithFractionalSeconds() {
        #expect(Date(rfc3339: "2026-03-24T10:30:00.000Z") != nil)
    }

    @Test func rfc3339WithoutFractionalSeconds() {
        #expect(Date(rfc3339: "2026-03-24T10:30:00Z") != nil)
    }

    @Test func rfc3339InvalidReturnsNil() {
        #expect(Date(rfc3339: "not-a-date") == nil)
    }

    @Test func parseEventDateTimeWithDateTime() {
        let dto = GCEventDateTime(dateTime: "2026-03-24T10:30:00Z", date: nil, timeZone: nil)
        let result = GoogleCalendarEvent.parseEventDateTime(dto)
        #expect(result != nil)
        #expect(result?.isAllDay == false)
    }

    @Test func parseEventDateTimeWithDateOnly() {
        let dto = GCEventDateTime(dateTime: nil, date: "2026-03-24", timeZone: nil)
        let result = GoogleCalendarEvent.parseEventDateTime(dto)
        #expect(result != nil)
        #expect(result?.isAllDay == true)
    }

    @Test func parseEventDateTimeWithNeitherReturnsNil() {
        let dto = GCEventDateTime(dateTime: nil, date: nil, timeZone: nil)
        #expect(GoogleCalendarEvent.parseEventDateTime(dto) == nil)
    }
}
