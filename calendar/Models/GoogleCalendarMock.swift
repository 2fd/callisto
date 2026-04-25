#if DEBUG
    import Foundation

    /// Factory for creating ``GoogleCalendar`` instances in tests and previews.
    enum GoogleCalendarMock {

        static func make(
            calendarId: String = "primary@gmail.com",
            accountId: String = "mock-account",
            etag: String = "\"etag1\"",
            summary: String = "Mock Calendar",
            backgroundColor: String = "#4285F4",
            accessRole: String = "owner",
            isVisible: Bool = true,
            calendarDescription: String? = nil,
            location: String? = nil,
            timeZone: String? = nil,
            summaryOverride: String? = nil,
            colorId: String? = nil,
            foregroundColor: String? = nil,
            isPrimary: Bool = false
        ) -> GoogleCalendar {
            let calendar = GoogleCalendar(
                calendarId: calendarId,
                accountId: accountId,
                etag: etag,
                summary: summary,
                backgroundColor: backgroundColor,
                accessRole: accessRole,
                isVisible: isVisible
            )
            calendar.calendarDescription = calendarDescription
            calendar.location = location
            calendar.timeZone = timeZone
            calendar.summaryOverride = summaryOverride
            calendar.colorId = colorId
            calendar.foregroundColor = foregroundColor
            calendar.isPrimary = isPrimary
            return calendar
        }

        static func primary(
            calendarId: String = "user@gmail.com",
            summary: String = "My Calendar"
        ) -> GoogleCalendar {
            make(calendarId: calendarId, summary: summary, isPrimary: true)
        }

        static func shared(
            calendarId: String = "shared@group.calendar.google.com",
            summary: String = "Shared Calendar"
        ) -> GoogleCalendar {
            make(calendarId: calendarId, summary: summary, accessRole: "reader")
        }

        static func invisible(
            calendarId: String = "invisible@group.calendar.google.com",
            summary: String = "Invisible Calendar"
        ) -> GoogleCalendar {
            make(calendarId: calendarId, summary: summary, isVisible: false)
        }
    }
#endif
