#if DEBUG
    import Foundation

    /// Factory for creating ``EventEntry`` instances in tests and previews.
    enum EventEntryMock {

        static func make(
            event: GoogleCalendarEvent,
            calendar: GoogleCalendar? = nil,
            account: GoogleAccount? = nil
        ) -> EventEntry {
            EventEntry(
                event: event,
                calendar: calendar ?? GoogleCalendarMock.primary(),
                account: account ?? GoogleAccountMock.primary()
            )
        }
    }
#endif
