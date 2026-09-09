import SwiftUI

/// Header bar for the popover with current month/year title, calendar link, and a gear button.
struct PopoverHeader: View {

  /// Called when the user taps the settings gear icon.
  var onSettings: (() -> Void)?

  var onRefresh: (() -> Void)?
  var isRefreshing: Bool = false

  var body: some View {
    HStack(spacing: 12) {
      Text(Date.now.format(f: "MMM yyyy"))
        .font(.system(size: 15, weight: .semibold))

      Spacer()

      if onRefresh != nil {
        Button(action: {
          if !isRefreshing {
            onRefresh!()
          }
        }) {
          Image(systemName: "arrow.counterclockwise")
            .font(.system(size: 16))
            .frame(width: 24, height: 28)
            .contentShape(Rectangle())
        }
        .disabled(isRefreshing)
        .eventHoverEffect()
        .buttonStyle(.plain)
        .help("Refresh events")
        .accessibilityLabel("Refresh events")
      }

      if onSettings != nil {
        Button(action: onSettings!) {
          Image(systemName: "gear")
            .font(.system(size: 16))
            .frame(width: 24, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .eventHoverEffect()
        .help("Settings")
        .accessibilityLabel("Settings")
      }
    }
    .padding(.horizontal, 12)
    .frame(height: UI.PanelHeaderHeight)
  }

}

#Preview("Base") {
  VStack {
    PopoverHeader()
  }.frame(width: UI.Width)
}

#Preview("onSettings") {
  VStack {
    PopoverHeader(onSettings: {})
  }.frame(width: UI.Width)
}

#Preview("onRefresh") {
  VStack {
    PopoverHeader(onSettings: {}, onRefresh: {})
  }.frame(width: UI.Width)
}

#Preview("isRefreshing") {
  VStack {
    PopoverHeader(onSettings: {}, onRefresh: {}, isRefreshing: true)
  }.frame(width: UI.Width)
}
