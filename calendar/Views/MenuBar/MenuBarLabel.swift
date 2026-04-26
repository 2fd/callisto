import SwiftUI
import os

/// A label view for the menu bar that shows the calendar icon, a time indicator, and the next upcoming event title.
///
/// The time indicator adapts based on how soon the event is:
/// - **In progress:** "Now"
/// - **Starting within 1 hour:** relative time like "in 15m"
/// - **Starting 1+ hours away:** absolute time like "2:00 PM"
///
/// Re-renders on every minute boundary via ``MinuteTicker`` read from the environment.
struct MenuBarLabel: View {

  var event: GoogleCalendarEvent?
  @Environment(MinuteScheduler.self) private var ticker

  var body: some View {
    let _ = ticker.now
    HStack(alignment: .center) {
      if let event {
        MenuBarEventLabel(event: event)
      } else {
        MenuBarEmptyLabel()
      }
    }
    .frame(maxWidth: UI.Width)
  }
}

struct MenuBarEmptyLabel: View {
  var body: some View {
    Text(Date.now.format(f: "d MMM").uppercased())
      .font(.headline)
  }
}

struct MenuBarEventLabel: View {

  let event: GoogleCalendarEvent
  @Environment(MinuteScheduler.self) private var ticker

  var body: some View {
    let _ = ticker.now
    HStack(alignment: .center, spacing: 6) {
      MenuBarEventIcon(event: event)
      Text(" \(prefix)\(event.summary)")
        .lineLimit(1)
        .truncationMode(.tail)
    }
  }

  private var prefix: String {
    if event.startDate.isBefore(.now) {
      return ""
    }

    if event.startDate.isToday {
      let diff = Int(ceil(event.startDate.timeIntervalSince(.now) / 60))
      if diff <= 60 {
        return "In \(diff)min: "
      }

      return "\(event.startDate.formatted(date: .omitted, time: .shortened)): "
    }

    if event.startDate.isTomorrow {
      return "Tomorrow: "
    }

    return
      "\(event.startDate.format(f: "EEE")), \(event.startDate.formatted(date: .omitted, time: .shortened)): "
  }
}

struct MenuBarEventIcon: View {
  let event: GoogleCalendarEvent
  var body: some View {
    if event.startDate.isBefore(.now) {
      ConferenceIconView(event: event)
    } else if event.startDate.isToday {
      let diff = Int(ceil(event.startDate.timeIntervalSince(.now) / 60))
      if diff <= 60 {
        Image(systemName: "timer")
      } else {
        Image(systemName: "ellipsis.calendar")
      }
    } else {
      Image(systemName: "moon.fill")
    }
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 10) {
    MenuBarEmptyLabel()
    MenuBarEventLabel(event: CalendarEventMock.now())
    MenuBarEventLabel(
      event: CalendarEventMock.today(startDate: .now.addingTimeInterval(30))
    )
    MenuBarEventLabel(
      event: CalendarEventMock.today(startDate: .now.addingTimeInterval(300))
    )
    MenuBarEventLabel(
      event: CalendarEventMock.today(
        startDate: .now.addingTimeInterval(3600 * 2)
      )
    )
    MenuBarEventLabel(event: CalendarEventMock.tomorrow())
    MenuBarEventLabel(event: CalendarEventMock.nextWeek())
  }
  .padding()
  .frame(maxWidth: UI.Width)
  .environment(MinuteScheduler())
}
