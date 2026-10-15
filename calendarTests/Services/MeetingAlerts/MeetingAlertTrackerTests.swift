import Foundation
import Testing

@testable import calendar

@Suite("MeetingAlertTracker")
@MainActor
struct MeetingAlertTrackerTests {

    private typealias F = MeetingAlertFixtures

    @Test func eachAlertIsRaisedOnce() {
        var tracker = MeetingAlertTracker()
        let entries = [F.entry("sync", start: 0)]

        #expect(tracker.update(entries: entries, now: F.at(minutes: 0)).delivered.count == 1)
        let next = tracker.update(entries: entries, now: F.at(minutes: 1))
        #expect(next.delivered.isEmpty)
        #expect(next.active.count == 1)
    }

    @Test func startingReplacesTheHeadsUp() {
        var tracker = MeetingAlertTracker()
        let standup = F.entry("standup", start: -30, duration: 60)
        let sync = F.entry("sync", start: 0)

        let early = tracker.update(entries: [standup, sync], now: F.at(minutes: -5))
        #expect(early.delivered.map(\.kind) == [.headsUp])

        let start = tracker.update(entries: [standup, sync], now: F.at(minutes: 0))
        #expect(start.expired.map(\.kind) == [.headsUp])
        #expect(start.delivered.map(\.kind) == [.starting])
        #expect(start.active.map(\.kind) == [.starting])
    }

    @Test func dismissedAlertsNeverComeBack() {
        var tracker = MeetingAlertTracker()
        let entries = [F.entry("sync", start: 0)]

        _ = tracker.update(entries: entries, now: F.at(minutes: 0))
        #expect(tracker.dismissActive().count == 1)
        #expect(tracker.active.isEmpty)

        let next = tracker.update(entries: entries, now: F.at(minutes: 1))
        #expect(next.isEmpty)
        #expect(next.active.isEmpty)
    }

    @Test func activeAlertsExpireWhenTheirEventEnds() {
        var tracker = MeetingAlertTracker()
        let entries = [F.entry("sync", start: 0, duration: 30)]

        _ = tracker.update(entries: entries, now: F.at(minutes: 0))
        let ended = tracker.update(entries: entries, now: F.at(minutes: 30))
        #expect(ended.expired.count == 1)
        #expect(ended.active.isEmpty)
    }

    @Test func activeAlertsExpireWhenTheirEventDisappears() {
        var tracker = MeetingAlertTracker()
        _ = tracker.update(entries: [F.entry("sync", start: 0)], now: F.at(minutes: 0))
        let gone = tracker.update(entries: [], now: F.at(minutes: 1))
        #expect(gone.expired.count == 1)
    }

    @Test func rescheduledEventIsRaisedAgainAtItsNewTime() {
        var tracker = MeetingAlertTracker()
        let sync = F.entry("sync", start: 0)
        _ = tracker.update(entries: [sync], now: F.at(minutes: 0))

        sync.event.startDate = F.at(minutes: 30)
        sync.event.endDate = F.at(minutes: 60)

        let moved = tracker.update(entries: [sync], now: F.at(minutes: 1))
        #expect(moved.expired.count == 1)
        #expect(moved.delivered.isEmpty)

        let again = tracker.update(entries: [sync], now: F.at(minutes: 30))
        #expect(again.delivered.map(\.kind) == [.starting])
    }

    @Test func headsUpDropsTheCurrentEventOnceItIsDeclined() {
        var tracker = MeetingAlertTracker()
        let standup = F.entry("standup", start: -30, duration: 60)
        let sync = F.entry("sync", start: 0)

        _ = tracker.update(entries: [standup, sync], now: F.at(minutes: -5))
        #expect(tracker.active.first?.currentId == standup.event.compositeId)

        standup.event.status = EventStatus.declined
        let change = tracker.update(entries: [standup, sync], now: F.at(minutes: -4))
        #expect(change.currentChanged)
        #expect(!change.isEmpty)
        #expect(change.active.first?.kind == .headsUp)
        #expect(change.active.first?.current == nil)
    }

    @Test func headsUpDropsTheCurrentEventOnceItEnds() {
        var tracker = MeetingAlertTracker()
        // Ends four minutes before the next one starts.
        let standup = F.entry("standup", start: -30, duration: 26)
        let sync = F.entry("sync", start: 0)

        _ = tracker.update(entries: [standup, sync], now: F.at(minutes: -5))
        let change = tracker.update(entries: [standup, sync], now: F.at(minutes: -4))
        #expect(change.currentChanged)
        #expect(change.active.first?.current == nil)
    }

    @Test func keptAlertsHoldTheLatestEntries() {
        var tracker = MeetingAlertTracker()
        let first = F.entry("sync", start: 0)
        _ = tracker.update(entries: [first], now: F.at(minutes: 0))

        // A sync replaces the model with an equal one.
        let replacement = F.entry("sync", start: 0)
        let change = tracker.update(entries: [replacement], now: F.at(minutes: 1))
        #expect(change.active.first?.entry.event === replacement.event)
    }

    @Test func raisedKeysArePrunedAfterADay() {
        var tracker = MeetingAlertTracker()
        _ = tracker.update(entries: [F.entry("sync", start: 0)], now: F.at(minutes: 0))
        #expect(tracker.raised.count == 1)

        _ = tracker.update(entries: [], now: F.at(minutes: Constants.meetingAlertRetention / 60))
        #expect(tracker.raised.isEmpty)
    }

    // MARK: - Content

    @Test func contentIsNilWithoutAlerts() {
        #expect(MeetingAlertContent(alerts: []) == nil)
    }

    @Test func startingAndHeadsUpDueTogetherAreBothShown() {
        // In A; B starts now and C is five minutes out.
        let a = F.entry("a", start: -60, duration: 120)
        let b = F.entry("b", start: 0)
        let c = F.entry("c", start: 5)

        let content = MeetingAlertContent(alerts: [
            MeetingAlert(entry: b, kind: .starting),
            MeetingAlert(entry: c, kind: .headsUp, current: a),
        ])
        #expect(content?.starting.map(\.id) == [b.id])
        #expect(content?.upNext.map(\.id) == [c.id])
        #expect(content?.current?.id == a.id)
    }

    @Test func currentIsNotRepeatedWhenItIsAlsoStarting() {
        let b = F.entry("b", start: 0)
        let c = F.entry("c", start: 5)

        let content = MeetingAlertContent(alerts: [
            MeetingAlert(entry: b, kind: .starting),
            MeetingAlert(entry: c, kind: .headsUp, current: b),
        ])
        #expect(content?.starting.map(\.id) == [b.id])
        #expect(content?.current == nil)
    }

    @Test func headsUpContentCarriesTheCurrentEvent() {
        let standup = F.entry("standup", start: -30, duration: 60)
        let sync = F.entry("sync", start: 0)

        let content = MeetingAlertContent(alerts: [
            MeetingAlert(entry: sync, kind: .headsUp, current: standup)
        ])
        #expect(content?.starting.isEmpty == true)
        #expect(content?.current?.id == standup.id)
        #expect(content?.upNext.map(\.id) == [sync.id])
    }

    @Test func alertIdentityIsCopiedOutOfTheModel() {
        let sync = F.entry("sync", start: 0)
        let alert = MeetingAlert(entry: sync, kind: .starting)

        sync.event.startDate = F.at(minutes: 30)
        #expect(alert.startDate == F.t0)
        #expect(alert.eventId == "cal1/sync")
        #expect(alert.id == MeetingAlertPolicy.key(eventId: "cal1/sync", kind: .starting, start: F.t0))
    }
}
