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
    .frame(maxWidth: UI.MenuBarMaxWidth)
  }
}

/// The status item's live label.
///
/// Reads the next event in its own `body` rather than taking it as a parameter:
/// ``MenuBarController`` builds this view once and hands it to an
/// `NSHostingView`, so anything resolved outside `body` would be frozen at
/// launch. Reading `eventManager` here keeps `@Observable` tracking intact.
struct MenuBarStatusLabel: View {

  @Environment(GoogleCalendarEventManager.self) private var eventManager

  var body: some View {
    MenuBarLabel(event: eventManager.next())
      .padding(.horizontal, 6)
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
    if event.isOutOfOffice {
      Image(systemName: "minus.circle.fill")
    } else if event.startDate.isBefore(.now) {
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

#if DEBUG

/// Draws label states on a menu bar strip, at menu bar size, in both menu bar
/// appearances.
///
/// The canvas' flat background is not what the status item renders against — the
/// bar takes its appearance from the desktop behind it, not from the app's
/// colour scheme — so a bare `#Preview` of ``MenuBarLabel`` shows contrast the
/// running app never has.
private struct MenuBarStripPreview<Content: View>: View {

  var colorScheme: ColorScheme = .dark
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(.horizontal, 6)
      .frame(height: UI.MenuBarHeight, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(colorScheme == .dark ? Color.black.opacity(0.75) : Color.white.opacity(0.75))
      .environment(\.colorScheme, colorScheme)
  }
}

/// Renders `content` the way `MenuBarExtra` renders its label — flattened to a
/// template image, so every colour collapses to the bar's tint.
///
/// Callisto hosts the label itself now (see ``MenuBarController``), so colour
/// survives at runtime. This stays as the side-by-side reference: if the two
/// rows below ever match again, the label has regressed to template rendering.
private struct TemplateFlattened<Content: View>: View {

  let content: Content

  var body: some View {
    if let image = flattened {
      Image(nsImage: image)
        .renderingMode(.template)
    } else {
      content
    }
  }

  private var flattened: NSImage? {
    let renderer = ImageRenderer(content: content)
    renderer.scale = 2

    guard let cgImage = renderer.cgImage else { return nil }

    let image = NSImage(
      cgImage: cgImage,
      size: NSSize(
        width: CGFloat(cgImage.width) / 2,
        height: CGFloat(cgImage.height) / 2
      )
    )
    // What AppKit does to a `MenuBarExtra` label: keep the alpha, discard the
    // colour, tint with the menu bar's foreground.
    image.isTemplate = true
    return image
  }
}

private struct MenuBarLabelGallery: View {

  let colorScheme: ColorScheme

  private var states: [(String, GoogleCalendarEvent?)] {
    [
      ("No events", nil),
      ("In progress", CalendarEventMock.now()),
      ("Within a minute", CalendarEventMock.today(startDate: .now.addingTimeInterval(30))),
      ("Within an hour", CalendarEventMock.today(startDate: .now.addingTimeInterval(300))),
      ("Later today", CalendarEventMock.today(startDate: .now.addingTimeInterval(3600 * 2))),
      ("Tomorrow", CalendarEventMock.tomorrow()),
      ("Next week", CalendarEventMock.nextWeek()),
      ("With conference link", CalendarEventMock.ongoingMeeting(summary: "Sprint planning")),
    ]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(Array(states.enumerated()), id: \.offset) { _, state in
        VStack(alignment: .leading, spacing: 3) {
          Text(state.0)
            .font(.caption2)
            .foregroundStyle(.secondary)

          MenuBarStripPreview(colorScheme: colorScheme) {
            MenuBarLabel(event: state.1)
          }

          MenuBarStripPreview(colorScheme: colorScheme) {
            TemplateFlattened(content: MenuBarLabel(event: state.1))
          }
        }
      }

      Text("Top row: what the status item shows. Bottom row: template rendering, what MenuBarExtra showed.")
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
    }
    .padding()
    .frame(width: UI.MenuBarMaxWidth + 40)
    .background(colorScheme == .dark ? Color(white: 0.13) : Color(white: 0.95))
    .environment(MinuteScheduler())
    .preferredColorScheme(colorScheme)
  }
}

#Preview("Menu Bar Label - Dark Bar") {
  MenuBarLabelGallery(colorScheme: .dark)
}

#Preview("Menu Bar Label - Light Bar") {
  MenuBarLabelGallery(colorScheme: .light)
}
#endif
