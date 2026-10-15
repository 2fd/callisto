import SwiftUI
import UserNotifications

/// Settings section choosing how an event about to start is announced.
///
/// When notifications are the chosen style but the user has turned them off in
/// System Settings, says so and links there — the app cannot ask twice.
struct MeetingAlertSettingsSection: View {

  @Environment(UserSettings.self) private var userSettings
  @Environment(MeetingNotifier.self) private var notifier

  var body: some View {
    @Bindable var settings = userSettings

    Section("Alerts") {
      Picker(selection: $settings.meetingAlertStyle) {
        ForEach(MeetingAlertStyle.allCases) { style in
          Text(style.label).tag(style)
        }
      } label: {
        VStack(alignment: .leading) {
          Text("Upcoming Events")
          Text(
            "When an event starts, and \(Self.headsUpMinutes) minutes before if you are in another one."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
      .pickerStyle(.menu)

      if settings.meetingAlertStyle == .notification && notifier.authorizationStatus == .denied {
        HStack {
          Text("Notifications are turned off for \(AppInfo.displayName).")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          Button("Open System Settings", action: openNotificationSettings)
        }
      }
    }
  }

  private static var headsUpMinutes: Int {
    Int((Constants.meetingHeadsUpLead / 60).rounded())
  }

  private func openNotificationSettings() {
    let bundleId = Bundle.main.bundleIdentifier ?? Constants.subsystem
    guard let url = URL(string: Constants.notificationSettingsURLPrefix + bundleId) else { return }
    NSWorkspace.shared.open(url)
  }
}
