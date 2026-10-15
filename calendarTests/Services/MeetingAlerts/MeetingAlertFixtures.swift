import Foundation

@testable import calendar

/// Builds entries on a fixed, minute-aligned clock so alert timing is exact.
@MainActor
enum MeetingAlertFixtures {

    /// The reference moment every test is written against.
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    static func at(minutes: Double) -> Date {
        t0.addingTimeInterval(minutes * 60)
    }

    /// A timed event starting `start` minutes after ``t0``.
    static func entry(
        _ id: String,
        start: Double,
        duration: Double = 30,
        status: String = "confirmed",
        isAllDay: Bool = false,
        eventType: String = "default",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> EventEntry {
        EventEntryMock.make(
            event: CalendarEventMock.make(
                compositeId: "cal1/\(id)",
                eventId: id,
                summary: id,
                startDate: at(minutes: start),
                endDate: at(minutes: start + duration),
                isAllDay: isAllDay,
                status: status,
                eventType: eventType,
                conferenceLink: conferenceLink,
                attendees: attendees
            )
        )
    }
}
