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
        VStack(spacing: 0) {
            PopoverHeader(onSettings: { openWindows(.settings) }, onRefresh: {
                Task.detached(priority: .background) {
                    await eventManager.sync()
                }
            }, isRefreshing: eventManager.isSyncing)

            Divider()
                .padding(.horizontal, 6)

            if accountManager.iter().filter(\.canRead).isEmpty {
                NoAccountsView(onManageAccount: { openWindows(.settings) })
            } else {
                EventListView(
                    days: eventManager.iterByDays(userSettings),
                    maxHeight: (NSScreen.main?.visibleFrame.height ?? 800) * 0.9
                )
            }
        }
        .frame(width: UI.Width)
    }
}
