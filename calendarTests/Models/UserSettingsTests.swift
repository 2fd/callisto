import Foundation
import Testing

@testable import calendar

@Suite("UserSettings")
@MainActor
struct UserSettingsTests {

    @Test func meetingAlertStyleDefaultsToNotification() {
        let settings = UserSettings(store: InMemorySettingsStore())
        #expect(settings.meetingAlertStyle == .notification)
    }

    @Test func meetingAlertStyleRoundTrips() {
        let store = InMemorySettingsStore()
        let settings = UserSettings(store: store)

        for style in MeetingAlertStyle.allCases {
            settings.meetingAlertStyle = style
            #expect(UserSettings(store: store).meetingAlertStyle == style)
        }
    }

    @Test func offIsKeptAlthoughItsRawValueIsZero() {
        // UserDefaults returns 0 for an unset integer, so `.off` must be read
        // through `object(forKey:)` to be told apart from "never set".
        let store = InMemorySettingsStore()
        UserSettings(store: store).meetingAlertStyle = .off
        #expect(UserSettings(store: store).meetingAlertStyle == .off)
    }

    @Test func unknownStoredStyleFallsBackToTheDefault() {
        let store = InMemorySettingsStore()
        store.set(99, forKey: DefaultsKey.meetingAlertStyle)
        #expect(UserSettings(store: store).meetingAlertStyle == .notification)
    }
}
