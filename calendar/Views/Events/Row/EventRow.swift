import SwiftUI

/// One event in the list: its title, its hours, and whatever it carries besides.
///
/// Every colour, weight and opacity here comes from ``EventRowStyle`` — this
/// view only lays them out. Tapping the row opens the meeting, or the event in
/// Google Calendar when there is none.
struct EventRow: View {
  let entry: EventEntry

  @State private var isHovering = false

  @Environment(\.colorScheme) private var colorScheme

  private var event: GoogleCalendarEvent { entry.event }

  var body: some View {
    let style = EventRowStyle(entry: entry, isDarkSurface: colorScheme == .dark)

    // The trailing spacer is what keeps the content block from stretching to
    // the row's full width; the header's own spacer sets where its badges land.
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 2) {
        header(style)

        if !style.isCompact {
          details(style)
        }
      }

      Spacer()
    }
    .opacity(style.contentOpacity)
    .padding(.vertical, 4)
    // The fill is inset 4 from the row edge; these keep the content off its
    // edge now that it is opaque, where the color bar used to do that job.
    .padding(.leading, 14)
    .padding(.trailing, 10)
    .contentShape(Rectangle())
    .onTapGesture {
      entry.open()
    }
    .contextMenu {
      EventRowContextMenu(entry: entry)
    }
    .onHover { hovering in
      isHovering = hovering
    }
    .background {
      EventRowBackground(style: style, isHovering: isHovering)
    }
  }

  /// Title, then the badges — and, for a row with no second line to put them on,
  /// its hours.
  @ViewBuilder
  private func header(_ style: EventRowStyle) -> some View {
    HStack {
      Text(event.summary)
        .font(.system(.body, design: .default))
        .fontWeight(style.titleWeight)
        .lineLimit(1)
        .strikethrough(style.isStruckThrough)
        .foregroundColor(style.title)

      Spacer()

      if style.showsInlineTime {
        EventTimeRange(event: event, style: style)
      }

      EventBadgeStrip(event: event, style: style)
    }
  }

  /// Hours on the left, where to be and how to join on the right.
  @ViewBuilder
  private func details(_ style: EventRowStyle) -> some View {
    HStack {
      EventTimeRange(event: event, style: style)

      Spacer()

      if style.showsAccessories {
        EventRowDetails(event: event)
          // The pin resolves `.secondary` against this, so it dims with the
          // rest of the row instead of against the window's palette.
          .foregroundStyle(style.detail)
      }
    }
  }
}

#if DEBUG
  #Preview("State Gallery") {
    let fixture = EventPreviewFixture.empty()

    return VStack(spacing: 2) {
      ForEach(EventPreviewFixture.rowGallery()) { entry in
        EventRow(entry: entry)
      }
    }
    .environment(fixture.eventManager)
    .environment(fixture.eventManager.accounts)
    .frame(width: UI.Width)
    .padding(.vertical, 8)
    .padding(.horizontal, 8)
    .background(Color(nsColor: .windowBackgroundColor))
  }
#endif
