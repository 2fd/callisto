import SwiftUI
import Testing

@testable import calendar

@Suite("EventRowStyle")
@MainActor
struct EventRowStyleTests {

    private func style(
        _ event: GoogleCalendarEvent,
        dark: Bool = false,
        now: Date = .now
    ) -> EventRowStyle {
        EventRowStyle(
            entry: EventEntryMock.make(event: event),
            isDarkSurface: dark,
            now: now
        )
    }

    // MARK: - Treatment

    @Test func meetingInProgressIsOngoing() {
        #expect(style(CalendarEventMock.ongoingMeeting()).treatment == .ongoing)
    }

    @Test func upcomingMeetingIsFilled() {
        #expect(style(CalendarEventMock.today()).treatment == .filled)
    }

    @Test func tentativeMeetingIsFilledAndStriped() {
        let style = style(CalendarEventMock.maybe())
        #expect(style.treatment == .filled)
        #expect(style.isStriped)
    }

    @Test func declinedCancelledAndUnansweredAreBordered() {
        #expect(style(CalendarEventMock.cancelled()).treatment == .bordered)
        #expect(style(CalendarEventMock.pendingConfirm()).treatment == .bordered)

        let declined = CalendarEventMock.today(status: EventStatus.declined)
        #expect(style(declined).treatment == .bordered)
    }

    @Test func stripesAreOnlyForFilledRows() {
        // A tentative meeting already underway is drawn as ongoing, and the
        // shimmer replaces the stripes rather than stacking with them.
        let underway = CalendarEventMock.ongoingMeeting(
            status: EventStatus.tentative
        )
        let style = style(underway)
        #expect(style.treatment == .ongoing)
        #expect(!style.isStriped)
    }

    @Test func declinedMeetingUnderwayStaysBordered() {
        let declined = CalendarEventMock.ongoingMeeting(
            status: EventStatus.declined
        )
        #expect(style(declined).treatment == .bordered)
    }

    @Test func allDayEventUnderwayIsNotOngoing() {
        // An all-day event covers "now" all day; it is not a meeting in progress.
        #expect(style(CalendarEventMock.allDay()).treatment == .filled)
        #expect(style(CalendarEventMock.birthday()).treatment == .filled)
    }

    @Test func ongoingIsJudgedAgainstTheGivenTime() {
        let event = CalendarEventMock.ongoingMeeting()
        let afterwards = event.endDate.addingTimeInterval(60)
        #expect(style(event, now: afterwards).treatment == .filled)
    }

    // MARK: - Layout decisions

    @Test func allDayAndOutOfOfficeRowsAreCompact() {
        #expect(style(CalendarEventMock.allDay()).isCompact)
        #expect(style(CalendarEventMock.birthday()).isCompact)
        #expect(style(CalendarEventMock.outOfOffice()).isCompact)
        #expect(!style(CalendarEventMock.today()).isCompact)
    }

    @Test func onlyTimedOutOfOfficeShowsItsHoursInTheHeader() {
        #expect(style(CalendarEventMock.outOfOffice()).showsInlineTime)

        let allDayOutOfOffice = CalendarEventMock.allDay(
            summary: "Out of Office",
            eventType: EventType.outOfOffice
        )
        #expect(!style(allDayOutOfOffice).showsInlineTime)
        #expect(!style(CalendarEventMock.today()).showsInlineTime)
    }

    @Test func declinedAndCancelledAreStruckThrough() {
        #expect(style(CalendarEventMock.cancelled()).isStruckThrough)

        let declined = CalendarEventMock.today(status: EventStatus.declined)
        #expect(style(declined).isStruckThrough)

        #expect(!style(CalendarEventMock.pendingConfirm()).isStruckThrough)
        #expect(!style(CalendarEventMock.today()).isStruckThrough)
    }

    // MARK: - Opacity

    @Test func pastEventsAreFadedContentAndFill() {
        let past = style(CalendarEventMock.yesterday())
        #expect(past.contentOpacity == 0.4)
        #expect(past.fillOpacity(isHovering: false) == 0.4)
        #expect(past.fillOpacity(isHovering: true) == 0.85 * 0.4)
        #expect(!past.showsAccessories)
    }

    @Test func upcomingEventsAreFullStrength() {
        let upcoming = style(CalendarEventMock.today())
        #expect(upcoming.contentOpacity == 1.0)
        #expect(upcoming.fillOpacity(isHovering: false) == 1.0)
        #expect(upcoming.fillOpacity(isHovering: true) == 0.85)
        #expect(upcoming.showsAccessories)
    }

    // MARK: - Colors

    @Test func borderedRowsDrawTheirTextInTheEventColor() {
        let bordered = style(CalendarEventMock.cancelled())
        #expect(bordered.title == bordered.tint)
        #expect(bordered.detail == bordered.tint)
        #expect(bordered.titleWeight == .light)
    }

    @Test func filledRowsDrawTheirTextOnTheEventColor() {
        let filled = style(CalendarEventMock.today())
        #expect(filled.title == filled.onTint)
        #expect(filled.detail == filled.onTint.opacity(0.85))
        #expect(filled.title != filled.tint)
        #expect(filled.titleWeight == .medium)
    }

    @Test func theSameEventIsTonedDownOnADarkSurface() {
        let event = CalendarEventMock.today()
        #expect(style(event, dark: false).tint != style(event, dark: true).tint)
    }
}
