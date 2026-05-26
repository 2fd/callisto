import SwiftUI

/// Compact update controls for the Settings window.
struct UpdatesSettingsSection: View {

  @Environment(AppUpdater.self) private var updater

  var body: some View {
    Section("Updates") {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Callisto \(appVersion)")
            .font(.body)
          Text("Build \(appBuild)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button("Check for Updates…") {
          updater.checkForUpdates()
        }
      }
      .padding(.vertical, 2)
    }
  }

  private var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
  }

  private var appBuild: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
  }
}
