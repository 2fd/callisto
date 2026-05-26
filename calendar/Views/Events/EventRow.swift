import SwiftData
import SwiftUI
import os

/// A row displaying a timed event with a color bar, time range, title, and optional location.
///
/// Tapping the row opens the event in Google Calendar.
struct EventRow: View {
  let entry: EventEntry

  @State var isHover = false

  private var event: GoogleCalendarEvent { entry.event }
  private var account: GoogleAccount { entry.account }
  private var calendar: GoogleCalendar { entry.calendar }

  var body: some View {
    HStack(alignment: .center) {
      RoundedRectangle(cornerRadius: 6)
        .fill(Color(hex: calendar.backgroundColor))
        .opacity(!withIndicator ? 0 : 1)
        .frame(width: 4, height: oneLiner ? 20 : 36)

      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(event.summary)
            .font(.system(.body, design: .default))
            .fontWeight(withBordered ? .light : .medium)
            .lineLimit(1)
            .strikethrough(withStrikethrough)
            .foregroundColor(
              withBordered
                ? Color(hex: calendar.backgroundColor) : Color.primary
            )

          Spacer()

          if event.isAllDay {
            if event.isOutOfOffice {
              Image(systemName: "minus.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 12, height: 12)
                .foregroundStyle(.secondary)
                .help("out of office")
              
            } else if event.isBirthday{
              Image(systemName: "gift")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 12, height: 12)
                .foregroundStyle(.secondary)
                .help("birthday")
              
            }
          } else if event.isOutOfOffice {
              EventRowTimeRange(event: event)
                .font(.caption)
                .strikethrough(withStrikethrough)
                .foregroundColor(
                  withBordered
                    ? Color(hex: calendar.backgroundColor) : Color.secondary
                )
          }

          if event.isImportant {
            Image(systemName: "exclamationmark.triangle.fill")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 12, height: 12)
              .foregroundStyle(.yellow)
              .help("important")
          }

          if event.allOtherAttendeesDeclined {
            Image(systemName: "person.2.slash.fill")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 12, height: 12)
              .foregroundStyle(Color(hex: calendar.backgroundColor))
              .help("all attendees declined")
          }

          if withPlay {
            Image(systemName: "play")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 12, height: 12)
              .foregroundStyle(.secondary)
          }
        }

        if !oneLiner {
          HStack {
            EventRowTimeRange(event: event)
              .font(.caption)
              .strikethrough(withStrikethrough)
              .foregroundColor(
                withBordered
                  ? Color(hex: calendar.backgroundColor) : Color.secondary
              )

            Spacer()
            if !event.isPast {
              EventActionButtons(event: event)
            }
          }
        }
      }

      Spacer()
    }
    .opacity(event.isPast ? 0.4 : 1.0)
    .padding(.vertical, 4)
    .padding(.leading, 10)
    .padding(.trailing, 4)
    .contentShape(Rectangle())
    .onTapGesture {
      openEventLink(event, account: account)
    }
    .contextMenu {
      EventRowContextMenu(entry: entry)
    }
    .onHover { hover in
      isHover = hover
    }
    .background {
      if withPlay {
        OngoingEventBackground(
          tint: Color(hex: calendar.backgroundColor),
          isHovering: isHover
        )

      } else if event.isOutOfOffice {
        RoundedRectangle(cornerRadius: 4)
          .fill(.red)
          .opacity(isHover ? 0.3 : 0.2)
          .padding(.horizontal, 4)

      } else if withBordered {
        RoundedRectangle(cornerRadius: 4)
          .fill(rowSurface)
          .opacity(isHover ? 0.85 : 1.0)
          .padding(.horizontal, 4)

        RoundedRectangle(cornerRadius: 4)
          .stroke(Color(hex: calendar.backgroundColor), lineWidth: 1)
          .opacity(0.5)
          .padding(.horizontal, 4)

      } else {

        if event.isTentative {
          DiagonalStripesPattern()
            .cornerRadius(6)
            .padding(.horizontal, 4)
            .opacity(isHover ? 0.5 : 0.3)
        }

        RoundedRectangle(cornerRadius: 6)
          .fill(rowSurface)
          .opacity(isHover ? 0.85 : 1.0)
          .padding(.horizontal, 4)
      }
    }
  }

  private var rowSurface: Color {
    Color(nsColor: NSColor.alternatingContentBackgroundColors[1])
  }

  private var oneLiner: Bool {
    event.isAllDay || event.isOutOfOffice
  }

  private var withBordered: Bool {
    event.isDeclined || event.isCancelled || event.needsAction
  }

  private var withStrikethrough: Bool {
    event.isDeclined || event.isCancelled
  }

  private var withIndicator: Bool {
    !withBordered && !event.isOutOfOffice
  }

  private var playableType: Bool {
    !event.isAllDay && !event.isBirthday && !event.isOutOfOffice
  }

  private var playableStatus: Bool {
    event.isAccepted || event.isConfirmed || event.isTentative
  }

  private var playableDate: Bool {
    event.startDate < Date.now && event.endDate > Date.now
  }

  private var withPlay: Bool {
    playableType && playableStatus && playableDate
  }

}

/// A moving calendar-tinted background for a meeting that is happening now.
private struct OngoingEventBackground: View {
  let tint: Color
  let isHovering: Bool

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Group {
      if #available(macOS 15.0, *) {
        if reduceMotion {
          OngoingEventMesh(tint: tint, phase: 0)
        } else {
          TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            OngoingEventMesh(
              tint: tint,
              phase: timeline.date.timeIntervalSinceReferenceDate
            )
          }
        }
      } else {
        RoundedRectangle(cornerRadius: 6)
          .fill(
            LinearGradient(
              colors: [tint.opacity(0.38), tint.opacity(0.12), tint.opacity(0.28)],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
      }
    }
    .opacity(isHovering ? 0.85 : 0.65)
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .padding(.horizontal, 4)
  }
}

@available(macOS 15.0, *)
private struct OngoingEventMesh: View {
  let tint: Color
  let phase: TimeInterval

  var body: some View {
    let horizontalDrift = Float(sin(phase * 0.8)) * 0.13
    let verticalDrift = Float(cos(phase * 0.65)) * 0.12

    MeshGradient(
      width: 3,
      height: 3,
      points: [
        SIMD2(0, 0), SIMD2(0.5, 0), SIMD2(1, 0),
        SIMD2(0, 0.5), SIMD2(0.5 + horizontalDrift, 0.5 + verticalDrift), SIMD2(1, 0.5),
        SIMD2(0, 1), SIMD2(0.5, 1), SIMD2(1, 1),
      ],
      colors: [
        tint.opacity(0.18), tint.opacity(0.42), tint.opacity(0.16),
        tint.opacity(0.4), tint.opacity(0.75), .accentColor.opacity(0.38),
        tint.opacity(0.16), .accentColor.opacity(0.3), tint.opacity(0.2),
      ]
    )
  }
}

struct EventRowTimeRange: View {
  let event: GoogleCalendarEvent

  @ViewBuilder
  var body: some View {
    if !(event.isOutOfOffice && event.isAllDay) {
      Text("\(start) - \(end)")
    }
  }

  private var start: String {
    event.startDate.formatted(date: .omitted, time: .shortened)
  }

  private var end: String {
    event.endDate.formatted(date: .omitted, time: .shortened)
  }
}

/// Draws parallel diagonal lines at 45 degrees.
struct DiagonalStripesPattern: View {
  var spacing: CGFloat = 12
  var lineWidth: CGFloat = 6
  var color: Color = .primary

  var body: some View {
    Canvas { context, size in
      let h = size.height
      let w = size.width
      var x: CGFloat = -h

      while x < w + h {
        var path = Path()
        path.move(to: CGPoint(x: x + h, y: -h))
        path.addLine(to: CGPoint(x: x - h * 2, y: h * 2))
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
        x += spacing + lineWidth
      }
    }
  }
}

#Preview("State Gallery") {
  let container = try! ModelContainer(
    for: Schema([
      GoogleAccount.self, GoogleCalendar.self, GoogleCalendarEvent.self,
      EventAttendee.self, EventAttachment.self, EventReminder.self,
    ]),
    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
  )
  let eventManager = GoogleCalendarEventManager(container: container)

  let entries = [
    EventEntryMock.make(event: CalendarEventMock.allDay()),
    EventEntryMock.make(
      event: CalendarEventMock.allDay(
        summary: "Out of Office",
        eventType: "outOfOffice"
      )
    ),
    EventEntryMock.make(event: CalendarEventMock.birthday()),
    EventEntryMock.make(
      event: CalendarEventMock.today(
        summary: "Past Event",
        startDate: .now.addingTimeInterval(-3600)
      )
    ),
    EventEntryMock.make(event: CalendarEventMock.ongoingMeeting()),
    EventEntryMock.make(event: CalendarEventMock.today()),
    EventEntryMock.make(
      event: CalendarEventMock.today(summary: "[IMPORTANT] Important Event")
    ),
    EventEntryMock.make(event: CalendarEventMock.cancelled()),
    EventEntryMock.make(event: CalendarEventMock.maybe()),
    EventEntryMock.make(event: CalendarEventMock.pendingConfirm()),
    EventEntryMock.make(event: CalendarEventMock.outOfOffice()),
    EventEntryMock.make(event: CalendarEventMock.withConference()),
    EventEntryMock.make(event: CalendarEventMock.allDeclined()),
    EventEntryMock.make(
      event: CalendarEventMock.today(summary: "[IMPORTANT] Urgent Review")
    ),
  ]

  return VStack(spacing: 2) {
    ForEach(entries) { entry in
      EventRow(entry: entry)
    }
  }
  .environment(eventManager)
  .environment(eventManager.accounts)
  .frame(width: UI.Width)
  .padding(.vertical, 8)
  .padding(.horizontal, 8)
  .background(Color(nsColor: .windowBackgroundColor))

}
