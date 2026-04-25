import SwiftData
import SwiftUI

/// Preference key used to measure the intrinsic height of the event list content.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Scrollable list of events grouped by day.
struct EventListView: View {
    /// Days to display, produced by ``GoogleCalendarEventManager/iterByDays(_:)``.
    let days: [EventDay]
    /// Maximum height the list is allowed to grow to before scrolling.
    var maxHeight: CGFloat = 600

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        if days.isEmpty {
            NoEventsView()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(days) { day in
                        DaySectionHeader(date: day.day)

                        ForEach(day.iter()) { entry in
                            EventRow(entry: entry)
                        }
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    }
                )
              
              .padding(.top, 8)
              .padding(.bottom, 20)
              .padding(.horizontal, 8)
            }
            .frame(height: contentHeight > 0 ? min(contentHeight, maxHeight) : nil)
            .frame(maxHeight: maxHeight)
            .onPreferenceChange(ContentHeightKey.self) { height in
                contentHeight = height
            }
        }
    }
}

/// Section header with a relative date label.
struct DaySectionHeader: View {
    let date: Date

    var body: some View {
        Text(date.format(f: "EEE dd"))
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

#Preview("Loaded") {
    let container = try! ModelContainer(
        for: Schema([
            GoogleAccount.self, GoogleCalendar.self, GoogleCalendarEvent.self,
            EventAttendee.self, EventAttachment.self, EventReminder.self,
        ]),
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    let eventManager = GoogleCalendarEventManager(container: container)

    let cal = Foundation.Calendar.current
    let today = cal.startOfDay(for: .now)
    let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
    let day3 = cal.date(byAdding: .day, value: 2, to: today)!
    let day4 = cal.date(byAdding: .day, value: 5, to: today)!

    func at(_ day: Date, _ hour: Int, _ minute: Int = 0) -> Date {
        cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }
    func endOf(_ day: Date) -> Date {
        cal.date(byAdding: .day, value: 1, to: day)!
    }

    let workCalendar = GoogleCalendarMock.make(
        calendarId: "work@example.com",
        accountId: "work-account",
        summary: "Work",
        backgroundColor: "#E67C73"
    )
    let teamCalendar = GoogleCalendarMock.make(
        calendarId: "team@group.calendar.google.com",
        summary: "Team",
        backgroundColor: "#33B679"
    )
    let workAccount = GoogleAccountMock.make(
        accountId: "work-account",
        email: "me@work.com",
        displayName: "Work",
        authuser: 1
    )

    // Day 1 — Today: status, response, ongoing/past variants
    let day1Entries: [EventEntry] = [
        EventEntryMock.make(event: CalendarEventMock.today(
            compositeId: "d1/past",
            summary: "Morning standup",
            startDate: .now.addingTimeInterval(-3 * 3600)
        )),
        EventEntryMock.make(event: CalendarEventMock.ongoingMeeting(
            summary: "Sprint planning"
        )),
        EventEntryMock.make(event: CalendarEventMock.withConference(
            summary: "Design review"
        )),
        EventEntryMock.make(event: CalendarEventMock.today(
            compositeId: "d1/important",
            summary: "[IMPORTANT] Quarterly review",
            startDate: at(today, 14)
        )),
        EventEntryMock.make(event: CalendarEventMock.maybe(
            summary: "Optional sync"
        )),
        EventEntryMock.make(event: CalendarEventMock.pendingConfirm(
            summary: "Pending invite"
        )),
        EventEntryMock.make(event: CalendarEventMock.cancelled(
            summary: "Cancelled meeting"
        )),
        EventEntryMock.make(event: CalendarEventMock.allDeclined(
            summary: "Everyone bailed"
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d1/location",
            eventId: "d1-location",
            summary: "1:1 with Sam",
            startDate: at(today, 16),
            endDate: at(today, 16, 30),
            location: "Room 4B"
        )),
    ]

    // Day 2 — Tomorrow: all-day + special types + long title
    let day2Entries: [EventEntry] = [
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d2/holiday",
            eventId: "d2-holiday",
            summary: "Company holiday",
            startDate: tomorrow,
            endDate: endOf(tomorrow),
            isAllDay: true
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d2/bday",
            eventId: "d2-bday",
            summary: "Jane's birthday",
            startDate: tomorrow,
            endDate: endOf(tomorrow),
            isAllDay: true,
            eventType: EventType.birthday
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d2/ooo-allday",
            eventId: "d2-ooo-allday",
            summary: "Out of office",
            startDate: tomorrow,
            endDate: endOf(tomorrow),
            isAllDay: true,
            eventType: EventType.outOfOffice,
            transparency: "transparent"
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d2/focus",
            eventId: "d2-focus",
            summary: "Focus time — deep work",
            startDate: at(tomorrow, 9),
            endDate: at(tomorrow, 11),
            eventType: EventType.focusTime
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d2/long",
            eventId: "d2-long",
            summary: "Strategic alignment session about the platform migration roadmap",
            startDate: at(tomorrow, 13),
            endDate: at(tomorrow, 14, 30),
            location: "HQ Building 2 — Room 401"
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d2/team",
            eventId: "d2-team",
            summary: "Team meeting",
            startDate: at(tomorrow, 15),
            endDate: at(tomorrow, 16),
            location: "Conference Room A",
            attendees: [
                EventAttendeeMock.organizer(),
                EventAttendeeMock.accepted(email: "alice@example.com", displayName: "Alice"),
                EventAttendeeMock.accepted(email: "bob@example.com", displayName: "Bob"),
            ]
        )),
    ]

    // Day 3 — Day after tomorrow: color variation, recurring, multi-account, private
    let day3Entries: [EventEntry] = [
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d3/recur",
            eventId: "d3-recur",
            summary: "Weekly standup",
            startDate: at(day3, 9, 30),
            endDate: at(day3, 10),
            recurringEventId: "recur-parent"
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d3/private",
            eventId: "d3-private",
            summary: "Private appointment",
            startDate: at(day3, 11),
            endDate: at(day3, 12),
            visibility: "private"
        )),
        EventEntryMock.make(
            event: CalendarEventMock.make(
                compositeId: "d3/work-zoom",
                eventId: "d3-work-zoom",
                accountId: "work-account",
                calendarId: "work@example.com",
                summary: "Customer call",
                startDate: at(day3, 13),
                endDate: at(day3, 14),
                conferenceLink: "https://zoom.us/j/123456789",
                conferenceSolutionName: "Zoom"
            ),
            calendar: workCalendar,
            account: workAccount
        ),
        EventEntryMock.make(
            event: CalendarEventMock.make(
                compositeId: "d3/team-green",
                eventId: "d3-team-green",
                calendarId: "team@group.calendar.google.com",
                summary: "Team sync",
                startDate: at(day3, 15),
                endDate: at(day3, 15, 30)
            ),
            calendar: teamCalendar
        ),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d3/ooo-timed",
            eventId: "d3-ooo-timed",
            summary: "Doctor's appointment",
            startDate: at(day3, 16),
            endDate: at(day3, 17),
            eventType: EventType.outOfOffice,
            transparency: "transparent"
        )),
    ]

    // Day 4 — Later this week: filler + working location to push past maxHeight
    let day4Entries: [EventEntry] = [
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d4/wfh",
            eventId: "d4-wfh",
            summary: "Working from home",
            startDate: day4,
            endDate: endOf(day4),
            isAllDay: true,
            eventType: EventType.workingLocation,
            transparency: "transparent"
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d4/design",
            eventId: "d4-design",
            summary: "Design sync",
            startDate: at(day4, 10),
            endDate: at(day4, 11)
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d4/coffee",
            eventId: "d4-coffee",
            summary: "Coffee chat",
            startDate: at(day4, 11, 30),
            endDate: at(day4, 12)
        )),
        EventEntryMock.make(event: CalendarEventMock.make(
            compositeId: "d4/demo",
            eventId: "d4-demo",
            summary: "Demo prep",
            startDate: at(day4, 14),
            endDate: at(day4, 15)
        )),
    ]

    let days: [EventDay] = [
        EventDay(day: today, entries: day1Entries),
        EventDay(day: tomorrow, entries: day2Entries),
        EventDay(day: day3, entries: day3Entries),
        EventDay(day: day4, entries: day4Entries),
    ]

    return EventListView(days: days)
        .environment(eventManager)
        .environment(eventManager.accounts)
        .frame(width: UI.Width)
}

#Preview("Empty") {
    let container = try! ModelContainer(
        for: Schema([
            GoogleAccount.self, GoogleCalendar.self, GoogleCalendarEvent.self,
            EventAttendee.self, EventAttachment.self, EventReminder.self,
        ]),
        configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
    )
    let eventManager = GoogleCalendarEventManager(container: container)

    return EventListView(days: [])
        .environment(eventManager)
        .environment(eventManager.accounts)
        .frame(width: UI.Width)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
}
