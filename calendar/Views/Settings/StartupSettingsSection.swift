import SwiftUI

struct StartupSettingsSection: View {
  @Environment(LoginItemService.self) private var loginItemService

  var body: some View {
    Section("Startup") {
      Toggle(isOn: openAtLoginBinding) {
        VStack(alignment: .leading) {
          Text("Open at Login")
          Text("Start \(AppInfo.displayName) when you log in.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .disabled(!loginItemService.canToggle)

      if let message = loginItemService.errorMessage ?? loginItemService.statusMessage {
        Text(message)
          .font(.caption)
          .foregroundStyle(loginItemService.errorMessage == nil ? Color.secondary : Color.red)
      }
    }
    .onAppear {
      loginItemService.refresh()
    }
  }

  private var openAtLoginBinding: Binding<Bool> {
    Binding {
      loginItemService.isEnabled
    } set: { isEnabled in
      loginItemService.setEnabled(isEnabled)
    }
  }
}
