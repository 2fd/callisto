import os
import SwiftUI

/// The main popover shown when the user clicks the menu bar icon.
///
/// Displays events only. Settings and account management live in the settings window.
struct Popover: View {
    @Environment(GoogleCalendarEventManager.self) private var eventManager
    @Environment(GoogleAccountManager.self) private var accountManager
    @Environment(UserSettings.self) private var userSettings
    @Environment(\.openWindows) private var openWindows

    var body: some View {
        PopoverContent(
            days: eventManager.iterByDays(userSettings),
            hasReadableAccounts: !accountManager.iter().filter(\.canRead).isEmpty,
            maxHeight: (NSScreen.main?.visibleFrame.height ?? 800) * 0.9,
            onSettings: { openWindows(.settings) },
            onRefresh: {
                Task.detached(priority: .background) {
                    await eventManager.sync()
                }
            },
            isRefreshing: eventManager.isSyncing
        )
    }
}

/// The renderable surface of the popover, separated from live data for previews.
struct PopoverContent: View {
    let days: [EventDay]
    let hasReadableAccounts: Bool
    let maxHeight: CGFloat
    let onSettings: () -> Void
    let onRefresh: () -> Void
    let isRefreshing: Bool

    var body: some View {
        VStack(spacing: 0) {
            PopoverHeader(
                onSettings: onSettings,
                onRefresh: onRefresh,
                isRefreshing: isRefreshing
            )

            Divider()
                .padding(.horizontal, 6)

            if !hasReadableAccounts {
                NoAccountsView(onManageAccount: onSettings)
            } else {
                EventListView(days: days, maxHeight: maxHeight)
            }
        }
        .frame(width: UI.Width)
    }
}

#if DEBUG
private struct PopoverReferencePreview: View {
    let colorScheme: ColorScheme

    var body: some View {
        let fixture = EventPreviewFixture.loaded()

        PopoverContent(
            days: fixture.days,
            hasReadableAccounts: true,
            maxHeight: 600,
            onSettings: {},
            onRefresh: {},
            isRefreshing: false
        )
        .environment(fixture.eventManager)
        .environment(fixture.eventManager.accounts)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(colorScheme)
    }
}

#Preview("Popover - Dark") {
    PopoverReferencePreview(colorScheme: .dark)
}

#Preview("Popover - Light") {
    PopoverReferencePreview(colorScheme: .light)
}
#endif
