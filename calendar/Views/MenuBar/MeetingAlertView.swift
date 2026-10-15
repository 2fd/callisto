import SwiftUI

/// Root of the alert panel. Built once and hosted by ``MenuBarController``, so it
/// reads the content from the model inside `body`, where `@Observable` sees it.
///
/// Holds the panel's width even while empty: the panel is anchored the moment
/// content arrives, before SwiftUI has laid it out, and a zero-width window
/// would be centred and clamped against the wrong size.
struct MeetingAlertPanel: View {
  let model: MeetingAlertModel

  var body: some View {
    VStack(spacing: 0) {
      if let content = model.content {
        MeetingAlertView(content: content)
      }
    }
    .frame(width: UI.Width)
  }
}

/// The alert hung under the status item when an event is about to start.
///
/// Each event is an ``EventRow``, unchanged: tapping it joins the meeting or
/// opens the event in Google Calendar, exactly as it does in the popover. What
/// the alert adds — section headers, the countdown, Dismiss — sits around the
/// rows, never inside them. There is no snooze: an alert is used or dismissed.
struct MeetingAlertView: View {
  let content: MeetingAlertContent

  var body: some View {
    PopoverChrome {
      VStack(alignment: .leading, spacing: 4) {
        if !content.starting.isEmpty {
          MeetingAlertHeader(title: "Starting now", detail: startingHint, tone: .accent)
          rows(content.starting)
        }

        if let first = content.upNext.first {
          if let current = content.current {
            CurrentEventSection(current: current)
          }
          MeetingAlertHeader(tone: .accent, title: "Up next") {
            CountdownText(to: first.event.startDate, style: .starts)
          }
          rows(content.upNext)
        }

        Button(action: dismissMeetingAlert) {
          Text("Dismiss")
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .padding(.top, 8)
      }
      .padding(12)
      .frame(width: UI.Width)
    }
  }

  private func rows(_ entries: [EventEntry]) -> some View {
    ForEach(entries) { entry in
      EventRow(entry: entry)
    }
  }

  /// Says what tapping the row does, when there is a single row to tap.
  private var startingHint: String? {
    guard content.starting.count == 1, let entry = content.starting.first else { return nil }
    return entry.meetingURL != nil
      ? String(localized: "click to join")
      : String(localized: "click to open in Calendar")
  }
}

/// "NOW · ends in N min" over the event the user is in. Drops out once that
/// event ends, which can happen before the event coming up starts.
private struct CurrentEventSection: View {
  let current: EventEntry

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      if current.event.endDate > context.date {
        VStack(alignment: .leading, spacing: 4) {
          MeetingAlertHeader(tone: .warning, title: "Now") {
            CountdownText(to: current.event.endDate, style: .ends)
          }
          EventRow(entry: current)
        }
      }
    }
  }
}

#if DEBUG
  private enum MeetingAlertPreview {
    static let meeting = EventEntryMock.make(
      event: CalendarEventMock.make(
        compositeId: "preview/sync",
        summary: "Design Sync",
        startDate: .now.addingTimeInterval(272),
        endDate: .now.addingTimeInterval(2072),
        conferenceLink: "https://meet.google.com/abc-defg-hij"
      )
    )
    static let lunch = EventEntryMock.make(
      event: CalendarEventMock.make(
        compositeId: "preview/lunch",
        summary: "Lunch",
        startDate: .now.addingTimeInterval(272),
        endDate: .now.addingTimeInterval(3872)
      )
    )
    static let standup = EventEntryMock.make(
      event: CalendarEventMock.make(
        compositeId: "preview/standup",
        summary: "Standup",
        startDate: .now.addingTimeInterval(-1500),
        endDate: .now.addingTimeInterval(300),
        conferenceLink: "https://meet.google.com/xyz-abcd-efg"
      )
    )

    static func starting(_ entry: EventEntry) -> MeetingAlertContent {
      MeetingAlertContent(
        alerts: [
          MeetingAlert(entry: entry, kind: .starting)
        ]
      )!
    }

    static func headsUp(_ entry: EventEntry) -> MeetingAlertContent {
      MeetingAlertContent(
        alerts: [
          MeetingAlert(entry: entry, kind: .headsUp, current: standup)
        ]
      )!
    }
  }

  #Preview("Starting - Dark") {
    MenuBarPreviewStage(colorScheme: .dark) {
      VStack(spacing: 16) {
        MeetingAlertView(content: MeetingAlertPreview.starting(MeetingAlertPreview.meeting))
        MeetingAlertView(content: MeetingAlertPreview.starting(MeetingAlertPreview.lunch))
      }
    }
  }

  #Preview("Heads-up - Dark") {
    MenuBarPreviewStage(colorScheme: .dark) {
      VStack(spacing: 16) {
        MeetingAlertView(content: MeetingAlertPreview.headsUp(MeetingAlertPreview.meeting))
        MeetingAlertView(content: MeetingAlertPreview.headsUp(MeetingAlertPreview.lunch))
      }
    }
  }

  #Preview("Heads-up - Light") {
    MenuBarPreviewStage(colorScheme: .light) {
      MeetingAlertView(content: MeetingAlertPreview.headsUp(MeetingAlertPreview.meeting))
    }
  }
#endif
