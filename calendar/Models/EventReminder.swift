import Foundation
import SwiftData

/// A reminder override on a calendar event, persisted via SwiftData.
///
/// Only present when the event does not use the calendar's default reminders
/// (`GoogleCalendarEvent.remindersUseDefault == false`).
@Model
final class EventReminder {
    /// The method used by this reminder: `"email"` or `"popup"`.
    var method: String
    /// Number of minutes before the event start when the reminder triggers.
    /// Valid range: 0 to 40320 (4 weeks).
    var minutes: Int

    /// The event this reminder belongs to.
    var event: GoogleCalendarEvent?

    init(method: String, minutes: Int) {
        self.method = method
        self.minutes = minutes
    }

    /// Creates a new reminder from a Google Calendar API reminder.
    /// Returns `nil` if the reminder has no method or minutes.
    convenience init?(from reminder: GCReminder) {
        guard let method = reminder.method, let minutes = reminder.minutes else { return nil }
        self.init(method: method, minutes: minutes)
    }
}
