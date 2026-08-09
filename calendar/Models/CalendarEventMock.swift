#if DEBUG
import Foundation

/// Factory for creating `GoogleCalendarEvent` instances in tests and previews.
///
/// Every parameter has a sensible default so call sites only need to specify
/// the properties they care about. Call ``make(...)`` to get a fully
/// configured model instance ready for insertion into a `ModelContext`.
enum CalendarEventMock {

    // MARK: - Defaults

    private static var defaultStart: Date { .now }
    private static var defaultEnd: Date { .now.addingTimeInterval(3600) }

    // MARK: - Factory

    /// Creates a `GoogleCalendarEvent` populated with reasonable defaults.
    ///
    /// Override only the parameters relevant to your test case.
    static func make(
        compositeId: String = "cal1/evt1",
        eventId: String = "evt1",
        accountId: String = "mock-account",
        calendarId: String = "cal1",
        etag: String = "\"etag1\"",
        iCalUID: String = "uid1@google.com",
        sequence: Int = 0,
        summary: String = "Mock Event",
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool = false,
        htmlLink: String = "https://calendar.google.com/event?eid=mock",
        status: String = "confirmed",
        eventType: String = EventType.default,
        eventDescription: String? = nil,
        location: String? = nil,
        colorId: String? = nil,
        startTimeZone: String? = nil,
        endTimeZone: String? = nil,
        endTimeUnspecified: Bool = false,
        transparency: String = "opaque",
        visibility: String = "default",
        creatorEmail: String? = nil,
        creatorDisplayName: String? = nil,
        creatorIsSelf: Bool = false,
        organizerEmail: String? = nil,
        organizerDisplayName: String? = nil,
        organizerIsSelf: Bool = false,
        recurringEventId: String? = nil,
        conferenceLink: String? = nil,
        conferenceSolutionName: String? = nil,
        conferenceSolutionIconUri: String? = nil,
        conferenceId: String? = nil,
        hangoutLink: String? = nil,
        conferenceNotes: String? = nil,
        guestsCanInviteOthers: Bool = true,
        guestsCanModify: Bool = false,
        guestsCanSeeOtherGuests: Bool = true,
        privateCopy: Bool = false,
        locked: Bool = false,
        attendeesOmitted: Bool = false,
        remindersUseDefault: Bool = true,
        sourceUrl: String? = nil,
        sourceTitle: String? = nil,
        attendees: [EventAttendee] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
    ) -> GoogleCalendarEvent {
        let event = GoogleCalendarEvent(
            compositeId: compositeId,
            eventId: eventId,
            accountId: accountId,
            calendarId: calendarId,
            etag: etag,
            iCalUID: iCalUID,
            sequence: sequence,
            summary: summary,
            startDate: startDate ?? defaultStart,
            endDate: endDate ?? defaultEnd,
            isAllDay: isAllDay,
            htmlLink: htmlLink,
            status: status,
            eventType: eventType
        )

        // Important prefix
        if summary.hasPrefix("[IMPORTANT]") {
            event.isImportant = true
            event.summary = String(summary.dropFirst("[IMPORTANT]".count)).trimmingCharacters(in: .whitespaces)
        }

        // Content
        event.eventDescription = eventDescription
        event.location = location
        event.colorId = colorId

        // Time
        event.startTimeZone = startTimeZone
        event.endTimeZone = endTimeZone
        event.endTimeUnspecified = endTimeUnspecified

        // Status & Visibility
        event.transparency = transparency
        event.visibility = visibility

        // People
        event.creatorEmail = creatorEmail
        event.creatorDisplayName = creatorDisplayName
        event.creatorIsSelf = creatorIsSelf
        event.organizerEmail = organizerEmail
        event.organizerDisplayName = organizerDisplayName
        event.organizerIsSelf = organizerIsSelf

        // Recurrence
        event.recurringEventId = recurringEventId

        // Conferencing
        event.conferenceLink = conferenceLink
        event.conferenceSolutionName = conferenceSolutionName
        event.conferenceSolutionIconUri = conferenceSolutionIconUri
        event.conferenceId = conferenceId
        event.hangoutLink = hangoutLink
        event.conferenceNotes = conferenceNotes

        // Guest Permissions
        event.guestsCanInviteOthers = guestsCanInviteOthers
        event.guestsCanModify = guestsCanModify
        event.guestsCanSeeOtherGuests = guestsCanSeeOtherGuests
        event.privateCopy = privateCopy
        event.locked = locked
        event.attendeesOmitted = attendeesOmitted

        // Reminders
        event.remindersUseDefault = remindersUseDefault

        // Source
        event.sourceUrl = sourceUrl
        event.sourceTitle = sourceTitle

        // Attendees
        event.attendees = attendees

        // Timestamps
        event.createdAt = createdAt
        event.updatedAt = updatedAt

        return event
    }

    // MARK: - Presets

    /// An event starting now (1-hour duration). Uses the `make()` defaults.
    static func now(
        compositeId: String = "cal1/now",
        summary: String = "Now Event",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "now",
            summary: summary,
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// A simple one-hour meeting happening now.
    static func ongoingMeeting(
        compositeId: String = "cal1/ongoing",
        summary: String = "Ongoing Meeting",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "ongoing",
            summary: summary,
            startDate: Date.now.addingTimeInterval(-1800),
            endDate: Date.now.addingTimeInterval(1800),
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// An all-day event for today.
    static func allDay(
        compositeId: String = "cal1/allday",
        summary: String = "All-Day Event",
        status: String = "confirmed",
        eventType: String = EventType.default,
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        let calendar = Foundation.Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return make(
            compositeId: compositeId,
            eventId: "allday",
            summary: summary,
            startDate: startOfDay,
            endDate: endOfDay,
            isAllDay: true,
            status: status,
            eventType: eventType,
            conferenceLink: conferenceLink,
            attendees: attendees,
        )
    }

    /// An event that ended yesterday (1-hour duration).
    static func yesterday(
        compositeId: String = "cal1/yesterday",
        summary: String = "Yesterday Event",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        let calendar = Foundation.Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now))!
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: yesterday)!
        return make(
            compositeId: compositeId,
            eventId: "yesterday",
            summary: summary,
            startDate: start,
            endDate: start.addingTimeInterval(3600),
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// An event happening later today (1-hour duration).
    static func today(
        compositeId: String = "cal1/today",
        summary: String = "Today Event",
        startDate: Date = Date.now.addingTimeInterval(600),
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        return make(
            compositeId: compositeId,
            eventId: "today",
            summary: summary,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3600),
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// An event happening tomorrow (1-hour duration).
    static func tomorrow(
        compositeId: String = "cal1/tomorrow",
        summary: String = "Tomorrow Event",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        let calendar = Foundation.Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))!
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow)!
        return make(
            compositeId: compositeId,
            eventId: "tomorrow",
            summary: summary,
            startDate: start,
            endDate: start.addingTimeInterval(3600),
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// An event happening next week (1-hour duration).
    static func nextWeek(
        compositeId: String = "cal1/next-week",
        summary: String = "Next Week Event",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        let calendar = Foundation.Calendar.current
        let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.startOfDay(for: .now))!
        let start = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nextWeek)!
        return make(
            compositeId: compositeId,
            eventId: "next-week",
            summary: summary,
            startDate: start,
            endDate: start.addingTimeInterval(3600),
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// A recurring event instance.
    static func recurring(
        compositeId: String = "cal1/recur-instance",
        summary: String = "Weekly Standup",
        recurringEventId: String = "recur-parent",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "recur-instance",
            summary: summary,
            startDate: Date.now.addingTimeInterval(3600),
            endDate: Date.now.addingTimeInterval(5400),
            status: status,
            recurringEventId: recurringEventId,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// An event with a Google Meet conference link.
    static func withConference(
        compositeId: String = "cal1/conf",
        summary: String = "Video Call",
        status: String = "confirmed",
        conferenceLink: String = "https://meet.google.com/abc-defg-hij",
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "conf",
            summary: summary,
            startDate: Date.now.addingTimeInterval(3600),
            endDate: Date.now.addingTimeInterval(7200),
            status: status,
            conferenceLink: conferenceLink,
            conferenceSolutionName: "Google Meet",
            attendees: attendees
        )
    }

    /// An event with attendees.
    static func withAttendees(
        compositeId: String = "cal1/meeting",
        summary: String = "Team Meeting",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee]? = nil
    ) -> GoogleCalendarEvent {
        let defaultAttendees = [
            EventAttendeeMock.organizer(),
            EventAttendeeMock.accepted(email: "alice@example.com", displayName: "Alice"),
            EventAttendeeMock.accepted(email: "bob@example.com", displayName: "Bob"),
        ]
        return make(
            compositeId: compositeId,
            eventId: "meeting",
            summary: summary,
            startDate: Date.now.addingTimeInterval(3600),
            endDate: Date.now.addingTimeInterval(7200),
            status: status,
            location: "Conference Room A",
            conferenceLink: conferenceLink,
            attendees: attendees ?? defaultAttendees
        )
    }

    /// A cancelled event.
    static func cancelled(
        compositeId: String = "cal1/cancelled",
        summary: String = "Cancelled Event",
        status: String = "cancelled",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "cancelled",
            summary: summary,
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// An out-of-office event.
    static func outOfOffice(
        compositeId: String = "cal1/ooo",
        summary: String = "Out of Office",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "ooo",
            summary: summary,
            status: status,
            eventType: EventType.outOfOffice,
            transparency: "transparent",
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// A focus time event.
    static func focusTime(
        compositeId: String = "cal1/focus",
        summary: String = "Focus Time",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "focus",
            summary: summary,
            status: status,
            eventType: EventType.focusTime,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// A working location event.
    static func workingLocation(
        compositeId: String = "cal1/wl",
        summary: String = "Working from Home",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "wl",
            summary: summary,
            isAllDay: true,
            status: status,
            eventType: EventType.workingLocation,
            transparency: "transparent",
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// A birthday event.
    static func birthday(
        compositeId: String = "cal1/bday",
        summary: String = "Jane's Birthday",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "bday",
            summary: summary,
            isAllDay: true,
            status: status,
            eventType: EventType.birthday,
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// A private/confidential event.
    static func privateEvent(
        compositeId: String = "cal1/private",
        summary: String = "Private Event",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee] = []
    ) -> GoogleCalendarEvent {
        make(
            compositeId: compositeId,
            eventId: "private",
            summary: summary,
            status: status,
            visibility: "private",
            conferenceLink: conferenceLink,
            attendees: attendees
        )
    }

    /// An event the current user tentatively accepted.
    static func maybe(
        compositeId: String = "cal1/maybe",
        summary: String = "Maybe Event",
        status: String = EventStatus.tentative,
        conferenceLink: String? = nil,
        attendees: [EventAttendee]? = nil
    ) -> GoogleCalendarEvent {
        // The organizer is someone else here: ``GoogleCalendarEvent`` reads the
        // *first* self attendee, so a self organizer would answer "accepted"
        // before the tentative one is reached.
        let defaultAttendees = [
            EventAttendeeMock.make(email: "boss@example.com", displayName: "Boss", responseStatus: "accepted", isOrganizer: true),
            EventAttendeeMock.make(email: "me@gmail.com", displayName: "Me", responseStatus: "tentative", isSelf: true),
            EventAttendeeMock.accepted(email: "alice@example.com", displayName: "Alice"),
        ]
        return make(
            compositeId: compositeId,
            eventId: "maybe",
            summary: summary,
            startDate: Date.now.addingTimeInterval(3600),
            endDate: Date.now.addingTimeInterval(7200),
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees ?? defaultAttendees
        )
    }

    /// An event the current user hasn't responded to yet.
    static func pendingConfirm(
        compositeId: String = "cal1/pending",
        summary: String = "Pending Event",
        status: String = EventStatus.needsAction,
        conferenceLink: String? = nil,
        attendees: [EventAttendee]? = nil
    ) -> GoogleCalendarEvent {
        // See ``maybe(...)``: the organizer has to be someone else for the self
        // attendee's pending response to be the one that counts.
        let defaultAttendees = [
            EventAttendeeMock.make(email: "boss@example.com", displayName: "Boss", responseStatus: "accepted", isOrganizer: true),
            EventAttendeeMock.make(email: "me@gmail.com", displayName: "Me", responseStatus: "needsAction", isSelf: true),
            EventAttendeeMock.accepted(email: "alice@example.com", displayName: "Alice"),
        ]
        return make(
            compositeId: compositeId,
            eventId: "pending",
            summary: summary,
            startDate: Date.now.addingTimeInterval(3600),
            endDate: Date.now.addingTimeInterval(7200),
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees ?? defaultAttendees
        )
    }

    /// An event where all other attendees have declined.
    static func allDeclined(
        compositeId: String = "cal1/all-declined",
        summary: String = "All Declined Event",
        status: String = "confirmed",
        conferenceLink: String? = nil,
        attendees: [EventAttendee]? = nil
    ) -> GoogleCalendarEvent {
        let defaultAttendees = [
            EventAttendeeMock.organizer(),
            EventAttendeeMock.declined(email: "alice@example.com", displayName: "Alice"),
            EventAttendeeMock.declined(email: "bob@example.com", displayName: "Bob"),
        ]
        return make(
            compositeId: compositeId,
            eventId: "all-declined",
            summary: summary,
            startDate: Date.now.addingTimeInterval(3600),
            endDate: Date.now.addingTimeInterval(7200),
            status: status,
            conferenceLink: conferenceLink,
            attendees: attendees ?? defaultAttendees
        )
    }
}
#endif
