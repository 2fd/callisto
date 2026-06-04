import SwiftUI

/// Compact update controls for the Settings window.
struct UpdatesSettingsSection: View {

  @Environment(AppUpdater.self) private var updater

  var body: some View {
    Section("Updates") {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("\(AppInfo.displayName) \(appVersion)")
            .font(.body)
          Text(appBuild)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("Check for Updates…") {
          updater.checkForUpdates()
        }
        .disabled(AppInfo.isNightlyBuild)
      }
      .padding(.vertical, 2)
    }
  }

  private var appVersion: String {
    AppInfo.version
  }

  private var appBuild: String {
    "\(AppInfo.isNightlyBuild ? "Build ID" : "Build") \(AppInfo.buildID)"
  }
}
