import SwiftUI

/// Placeholder view shown when there are no upcoming events to display.
struct NoEventsView: View {
    
    var onRefresh: (() -> Void)?
    var loading: Bool = false
    
    var body: some View {
            ContentUnavailableView {
                Label("No upcoming events", systemImage: "calendar")
            } description: {
                Text("Nothing scheduled in the next few days.")
            } actions: {
                if loading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                } else {
                    
                    if onRefresh != nil {
                        Button { onRefresh!() }
                        label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(loading)
                        .eventHoverEffect()
                    }
                    
                }
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}

#Preview("Base") {
    NoEventsView()
}


#Preview("onRefresh") {
    NoEventsView(onRefresh: {})
}


#Preview("onRefresh/Loading") {
    NoEventsView(onRefresh: {}, loading: true)
}
