import Foundation
import Testing

@testable import calendar

@Suite("MeetingAlertPolicy")
@MainActor
struct MeetingAlertPolicyTests {

    private typealias F = MeetingAlertFixtures

    private func due(_ entries: [EventEntry], at minutes: Double, alerted: Set<String> = []) -> [MeetingAlert] {
        MeetingAlertPolicy.due(entries: entries, now: F.at(minutes: minutes), alerted: alerted)
    }

    // MARK: - Nothing else in progress

    @Test func freeUserIsAlertedWhenTheEventStarts() {
        let alerts = due([F.entry("sync", start: 0)], at: 0)
        #expect(alerts.map(\.kind) == [.starting])
        #expect(alerts.first?.current == nil)
    }

    @Test func freeUserGetsNoHeadsUp() {
        #expect(due([F.entry("sync", start: 0)], at: -5).isEmpty)
    }

    @Test func nothingIsDueBetweenTheMoments() {
        let entries = [F.entry("sync", start: 0)]
        #expect(due(entries, at: -10).isEmpty)
        #expect(due(entries, at: -1).isEmpty)
    }

    // MARK: - Another event in progress

    @Test func busyUserGetsAHeadsUpFiveMinutesEarly() {
        let standup = F.entry("standup", start: -30, duration: 60)
        let sync = F.entry("sync", start: 0)

        let alerts = due([standup, sync], at: -5)
        #expect(alerts.map(\.kind) == [.headsUp])
        #expect(alerts.first?.entry.id == sync.id)
        #expect(alerts.first?.current?.id == standup.id)
    }

    @Test func busyUserIsAlsoAlertedAtTheStart() {
        let standup = F.entry("standup", start: -30, duration: 60)
        let sync = F.entry("sync", start: 0)
        #expect(due([standup, sync], at: 0).map(\.kind) == [.starting])
    }

    @Test func backToBackEventsGetAHeadsUp() {
        // The current event ends exactly when the next one starts.
        let standup = F.entry("standup", start: -30, duration: 30)
        let sync = F.entry("sync", start: 0)
        #expect(due([standup, sync], at: -5).map(\.kind) == [.headsUp])
    }

    @Test func eventsWithoutAMeetingAreAlertedToo() {
        let lunch = F.entry("lunch", start: 0)
        #expect(lunch.meetingURL == nil)
        #expect(due([lunch], at: 0).map(\.kind) == [.starting])
    }

    @Test func overlappingEventsReportTheOneEndingFirstAsCurrent() {
        let long = F.entry("long", start: -60, duration: 120)
        let short = F.entry("short", start: -20, duration: 30)
        let sync = F.entry("sync", start: 0)

        let alerts = due([long, short, sync], at: -5)
        #expect(alerts.first?.current?.id == short.id)
    }

    @Test func declinedOrAllDayEventsDoNotMakeTheUserBusy() {
        let sync = F.entry("sync", start: 0)
        let declined = F.entry("declined", start: -30, duration: 60, status: EventStatus.declined)
        let allDay = F.entry("allday", start: -600, duration: 1440, isAllDay: true)

        #expect(due([declined, sync], at: -5).isEmpty)
        #expect(due([allDay, sync], at: -5).isEmpty)
    }

    @Test func busyStatusIsJudgedAtTheMomentOfTheHeadsUp() {
        // The other event only starts after the heads-up moment has passed.
        let lateStart = F.entry("late", start: -2, duration: 30)
        let sync = F.entry("sync", start: 0)
        #expect(due([lateStart, sync], at: -5).isEmpty)
        #expect(due([lateStart, sync], at: -3).isEmpty)
    }

    // MARK: - Grace

    @Test func startingStaysDueForTheGracePeriod() {
        let entries = [F.entry("sync", start: 0)]
        #expect(due(entries, at: 1).map(\.kind) == [.starting])
        #expect(due(entries, at: 2).isEmpty)
    }

    @Test func headsUpStaysDueForTheGracePeriod() {
        let standup = F.entry("standup", start: -30, duration: 60)
        let sync = F.entry("sync", start: 0)
        #expect(due([standup, sync], at: -4).map(\.kind) == [.headsUp])
        #expect(due([standup, sync], at: -3).isEmpty)
    }

    // MARK: - Which events

    @Test func declinedCancelledAndAllDayEventsAreNeverAlerted() {
        let entries = [
            F.entry("declined", start: 0, status: EventStatus.declined),
            F.entry("cancelled", start: 0, status: EventStatus.cancelled),
            F.entry("allday", start: 0, duration: 1440, isAllDay: true),
        ]
        #expect(due(entries, at: 0).isEmpty)
    }

    @Test func tentativeAndTimedOutOfOfficeEventsAreAlerted() {
        let entries = [
            F.entry("maybe", start: 0, status: EventStatus.tentative),
            F.entry("ooo", start: 0, eventType: EventType.outOfOffice),
        ]
        #expect(due(entries, at: 0).count == 2)
    }

    @Test func eventDeclinedThroughTheSelfAttendeeIsNotAlerted() {
        // Google never sends status "declined": a decline is the user's own
        // attendee response on a confirmed event.
        let declined = F.entry(
            "sync",
            start: 0,
            attendees: [EventAttendeeMock.make(email: "me@example.com", responseStatus: "declined", isSelf: true)]
        )
        #expect(declined.event.status == EventStatus.confirmed)
        #expect(due([declined], at: 0).isEmpty)
    }

    @Test func eventAlreadyOverIsNotAnnouncedOnALateTick() {
        // A one-minute event and a Mac waking a minute and a half later.
        #expect(due([F.entry("blip", start: 0, duration: 1)], at: 1).isEmpty)
    }

    @Test func zeroLengthEventIsAnnouncedAndLastsItsGrace() {
        let deadline = F.entry("deadline", start: 0, duration: 0)
        #expect(due([deadline], at: 0).map(\.kind) == [.starting])

        let alert = MeetingAlert(entry: deadline, kind: .starting)
        #expect(!MeetingAlertPolicy.isExpired(alert, in: [deadline], now: F.at(minutes: 1)))
        #expect(MeetingAlertPolicy.isExpired(alert, in: [deadline], now: F.at(minutes: 2)))
    }

    @Test func workingLocationBlocksNeitherAlertNorMakeTheUserBusy() {
        let office = F.entry("office", start: -60, duration: 240, eventType: EventType.workingLocation)
        let sync = F.entry("sync", start: 0)

        #expect(due([F.entry("office", start: 0, eventType: EventType.workingLocation)], at: 0).isEmpty)
        #expect(due([office, sync], at: -5).isEmpty)
    }

    @Test func windowCoversEverythingThatCanBeDue() {
        let now = F.t0
        let window = MeetingAlertPolicy.window(around: now)
        // A start still inside its grace, and a heads-up at the end of its grace.
        #expect(window.contains(now.addingTimeInterval(-Constants.meetingAlertGrace + 1)))
        #expect(window.contains(
            now.addingTimeInterval(Constants.meetingHeadsUpLead + Constants.meetingAlertGrace - 1)
        ))
    }

    @Test func simultaneousStartsAreAllAlertedInOrder() {
        let b = F.entry("b", start: 0)
        let a = F.entry("a", start: -1)
        let alerts = due([b, a], at: 0)
        #expect(alerts.map(\.entry.id) == [a.id, b.id])
    }

    // MARK: - Keys

    @Test func alreadyAlertedIsSkipped() {
        let entries = [F.entry("sync", start: 0)]
        let first = due(entries, at: 0)
        #expect(due(entries, at: 1, alerted: Set(first.map(\.id))).isEmpty)
    }

    @Test func keysDifferByKindAndStart() {
        let starting = MeetingAlertPolicy.key(eventId: "cal1/sync", kind: .starting, start: F.t0)
        let headsUp = MeetingAlertPolicy.key(eventId: "cal1/sync", kind: .headsUp, start: F.t0)
        let moved = MeetingAlertPolicy.key(eventId: "cal1/sync", kind: .starting, start: F.at(minutes: 30))
        #expect(starting != headsUp)
        #expect(starting != moved)
    }

    @Test func rescheduledEventIsAlertedAgain() {
        let sync = F.entry("sync", start: 0)
        let first = due([sync], at: 0)

        sync.event.startDate = F.at(minutes: 30)
        sync.event.endDate = F.at(minutes: 60)
        #expect(due([sync], at: 30, alerted: Set(first.map(\.id))).map(\.kind) == [.starting])
    }

    // MARK: - Expiry

    private func starting(_ entry: EventEntry) -> MeetingAlert {
        MeetingAlert(entry: entry, kind: .starting)
    }

    @Test func alertExpiresWhenItsEventEnds() {
        let sync = F.entry("sync", start: 0, duration: 30)
        let alert = starting(sync)
        #expect(!MeetingAlertPolicy.isExpired(alert, in: [sync], now: F.at(minutes: 29)))
        #expect(MeetingAlertPolicy.isExpired(alert, in: [sync], now: F.at(minutes: 30)))
    }

    @Test func alertExpiresWhenItsEventIsRemovedDeclinedOrMoved() {
        let sync = F.entry("sync", start: 0)
        let alert = starting(sync)
        let now = F.at(minutes: 1)

        #expect(MeetingAlertPolicy.isExpired(alert, in: [], now: now))

        sync.event.status = EventStatus.declined
        #expect(MeetingAlertPolicy.isExpired(alert, in: [sync], now: now))

        sync.event.status = EventStatus.confirmed
        sync.event.startDate = F.at(minutes: 15)
        #expect(MeetingAlertPolicy.isExpired(alert, in: [sync], now: now))
    }

    @Test func headsUpExpiresWhenTheEventStarts() {
        let sync = F.entry("sync", start: 0)
        let headsUp = MeetingAlert(entry: sync, kind: .headsUp)
        #expect(!MeetingAlertPolicy.isExpired(headsUp, in: [sync], now: F.at(minutes: -1)))
        #expect(MeetingAlertPolicy.isExpired(headsUp, in: [sync], now: F.at(minutes: 0)))
    }
}
