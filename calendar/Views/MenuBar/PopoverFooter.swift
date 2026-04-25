import SwiftUI

/// Footer bar showing sync status and a manual refresh button.
struct PopoverFooter: View {
    /// When the last sync completed, or `nil` if never synced.
    var refreshedAt: Date?
    
    /// Called when the user taps the refresh button.
    var onRefresh: (() -> Void)?
    
    /// Whether a sync is currently in progress.
    var loading: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                if refreshedAt != nil {
                    SyncLabel(since: refreshedAt!)
                }

                Spacer()


                    if loading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 14, height: 14)
                    } else if onRefresh != nil {
                        Button(action: onRefresh!) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Refresh")
                    }
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

struct SyncLabel: View {
    
    let since: Date
    
    var body: some View {
        Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    
    
    
    /// Formats a relative time string using minute-level granularity.
    private var label:  String {
        let seconds = Int(Date.now.timeIntervalSince(since))
        if seconds < 60 {
            return "Synced less than a minute ago"
        }
        
        let minutes = seconds / 60
        if minutes < 60 {
            return minutes == 1 ? "Synced 1 minute ago" : "Synced \(minutes) minutes ago"
        }
        
        let hours = minutes / 60
        if hours < 24 {
            return hours == 1 ? "Synced 1 hour ago" : "Synced \(hours) hours ago"
        }
        
        let days = hours / 24
        return days == 1 ? "Synced 1 day ago" : "Synced \(days) days ago"
    }
}

#Preview("Base") {
    VStack {
    PopoverFooter(onRefresh: {})
    }.frame(width: UI.Width)
}

#Preview("Loading") {
    VStack {
    PopoverFooter(onRefresh: {}, loading: true)
    }.frame(width: UI.Width)
}

#Preview("Synced") {
    VStack {
        PopoverFooter(refreshedAt: Date.now, onRefresh: {})
        PopoverFooter(refreshedAt: Date.now.addingTimeInterval(-60), onRefresh: {})
        PopoverFooter(refreshedAt: Date.now.addingTimeInterval(-600), onRefresh: {})
        PopoverFooter(refreshedAt: Date.now.addingTimeInterval(-3600), onRefresh: {})
        PopoverFooter(refreshedAt: Date.now.addingTimeInterval(-36000), onRefresh: {})
        PopoverFooter(refreshedAt: Date.now.addingTimeInterval(-360000), onRefresh: {})
    }.frame(width: UI.Width)
}
