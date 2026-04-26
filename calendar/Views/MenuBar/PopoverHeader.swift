import SwiftUI

/// Header bar for the popover with current month/year title, calendar link, and a gear button.
struct PopoverHeader: View {

  /// Called when the user taps the settings gear icon.
  var onSettings: (() -> Void)?

  var onRefresh: (() -> Void)?
  var isRefreshing: Bool = false

  var body: some View {
    HStack(spacing: 8) {
      Text(Date.now.format(f: "MMM yyyy").uppercased())
        .font(.title3)

      Spacer()

      if onRefresh != nil {
        Button(action: {
          if !isRefreshing {
            onRefresh!()
          }
        }) {
          Image(systemName: "arrow.counterclockwise")
            .frame(width: 16)
        }
        .disabled(isRefreshing)
        .eventHoverEffect()
        .buttonStyle(.plain)
        .help("Settings")
      }

      if onSettings != nil {
        Button(action: onSettings!) {
          Image(systemName: "gear")
            .frame(width: 16)
        }
        .buttonStyle(.plain)
        .eventHoverEffect()
        .help("Settings")
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 4)
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
