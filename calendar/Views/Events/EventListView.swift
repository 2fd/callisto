import SwiftUI

/// Preference key used to measure the intrinsic height of the event list content.
private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Scrollable list of events grouped by day.
struct EventListView: View {
    /// Days to display, produced by ``GoogleCalendarEventManager/iterByDays(_:)``.
    let days: [EventDay]
    /// Maximum height the list is allowed to grow to before scrolling.
    var maxHeight: CGFloat = 600

    @State private var contentHeight: CGFloat = 0

    var body: some View {
        if days.isEmpty {
            NoEventsView()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(days) { day in
                        DaySectionHeader(date: day.day)

                        ForEach(day.iter()) { entry in
                            EventRow(entry: entry)
                        }
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                    }
                )
              
              .padding(.top, 8)
              .padding(.bottom, 20)
              .padding(.horizontal, 4)
              .padding(.trailing, 8)
            }
            .frame(height: contentHeight > 0 ? min(contentHeight, maxHeight) : nil)
            .frame(maxHeight: maxHeight)
            .onPreferenceChange(ContentHeightKey.self) { height in
                contentHeight = height
            }
        }
    }
}

/// Section header with a relative date label.
struct DaySectionHeader: View {
    let date: Date

    var body: some View {
      Text(date.format(f: "EEE dd").uppercased())
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 1)
    }
}

#Preview("State Gallery - Loaded") {
    let fixture = EventPreviewFixture.loaded()

    return MenuBarPreviewStage {
        PopoverChrome {
            EventListView(days: fixture.days)
                .frame(width: UI.Width)
        }
        .environment(fixture.eventManager)
        .environment(fixture.eventManager.accounts)
    }
}

#Preview("State Gallery - Empty") {
    let fixture = EventPreviewFixture.empty()

    return MenuBarPreviewStage {
        PopoverChrome {
            EventListView(days: [])
                .frame(width: UI.Width)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
        }
        .environment(fixture.eventManager)
        .environment(fixture.eventManager.accounts)
    }
}
