import SwiftUI

/// Opens the full calendar beyond the days shown in the panel.
struct PopoverFooter: View {
    var onMoreEvents: () -> Void

    var body: some View {
        Button(action: onMoreEvents) {
            Text("More events…")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: UI.PanelFooterHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .eventHoverEffect()
        .help("Open Google Calendar")
    }
}

#Preview {
    PopoverFooter(onMoreEvents: {}).frame(width: UI.Width)
}
