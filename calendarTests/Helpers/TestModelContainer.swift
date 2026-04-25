import Foundation
import SwiftData
@testable import calendar

@MainActor
enum TestModelContainer {
    static func create() throws -> ModelContainer {
        let schema = Schema([
            GoogleAccount.self,
            GoogleCalendar.self,
            GoogleCalendarEvent.self,
            EventAttendee.self,
            EventAttachment.self,
            EventReminder.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
