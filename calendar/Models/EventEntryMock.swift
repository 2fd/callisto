#if DEBUG
    import Foundation

    /// Factory for creating ``EventEntry`` instances in tests and previews.
    enum EventEntryMock {

        /// Resolves ``EventEntry/color`` exactly as ``GoogleCalendarManager``
        /// does, so a mock event carrying a `colorId` previews in that color.
        static func make(
            event: GoogleCalendarEvent,
            calendar: GoogleCalendar? = nil,
            account: GoogleAccount? = nil,
            palette: ColorPalette = .googleDefaults
        ) -> EventEntry {
            let calendar = calendar ?? GoogleCalendarMock.primary()
            return EventEntry(
                event: event,
                calendar: calendar,
                account: account ?? GoogleAccountMock.primary(),
                color: palette.event(event.colorId)
                    ?? palette.calendar(calendar.colorId)
                    ?? calendar.backgroundColor
            )
        }
    }
#endif
