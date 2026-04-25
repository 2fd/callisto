import SwiftData
import SwiftUI

private let refreshIntervalOptions: [(value: Int, label: String)] = [
  (1, "1 minute"),
  (2, "2 minutes"),
  (5, "5 minutes"),
  (10, "10 minutes"),
  (15, "15 minutes"),
  (30, "30 minutes"),
  (60, "1 hour"),
]

private let daysAheadOptions: [(value: Int, label: String)] = [
  (1, "1 day"),
  (2, "2 days"),
  (3, "3 days"),
  (7, "1 week"),
  (14, "2 weeks"),
  (30, "1 month"),
]

/// Settings window with accounts, sync options, and display preferences.
struct SettingsWindow: View {

  @Environment(GoogleAccountManager.self) private var accountManager
  @Environment(GoogleCalendarManager.self) private var calendarManager
  @Environment(GoogleCalendarEventManager.self) private var eventManager
  @Environment(UserSettings.self) private var userSettings

  var body: some View {
    @Bindable var settings = userSettings
    VStack {

      Form {
        Section("Sync") {
          Picker(selection: $settings.refreshIntervalMinutes) {
            ForEach(refreshIntervalOptions, id: \.value) { option in
              Text(option.label).tag(option.value)
            }
          } label: {
            VStack(alignment: .leading) {
              Text("Refresh Interval")
              Text("How often to fetch.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .pickerStyle(.menu)

          Picker(selection: $settings.showDaysAhead) {
            ForEach(daysAheadOptions, id: \.value) { option in
              Text(option.label).tag(option.value)
            }
          } label: {
            VStack(alignment: .leading) {
              Text("Days Ahead")
              Text("How far ahead to show.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .pickerStyle(.menu)

          Toggle(isOn: $settings.showDeclinedEvents) {
            VStack(alignment: .leading) {
              Text("Show Declined Events")
              Text("Include declined events.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }

        if !accountManager.isEmpty {
          ForEach(accountManager.iter(), id: \.accountId) { account in
            Section(account.email) {
              AccountSettingsRow(account: account)
              AccountCalendarSettingsRow(account: account)
              ForEach(
                calendarManager.iterByAccount(
                  accountId: account.accountId
                )
              ) { calendar in
                CalendarSettingsRow(account: account, calendar: calendar)
              }

              AccountRemove(account: account)
            }
          }
        }
        
        AccountAdd()
      }
      .formStyle(.grouped)
    }
    .frame(width: 400)
    .frame(minHeight: 600)

  }

  /// A single account with expandable calendar toggles.
  private struct AccountSettingsRow: View {
    let account: GoogleAccount
    @Environment(GoogleAccountManager.self) private var accountManager
    @Environment(GoogleCalendarManager.self) private var calendarManager
    @Environment(GoogleCalendarEventManager.self) private var eventManager
    @State private var isExpanded = false
    @State private var isReauthorizing = false

    private var accountCalendars: [GoogleCalendar] {
      calendarManager.forAccount(account.accountId)
        .sorted {
          $0.summary.localizedCaseInsensitiveCompare($1.summary)
            == .orderedAscending
        }
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 6) {

        HStack {
          VStack(alignment: .leading, spacing: 0) {
            Text("Authuser:")
            Text("Google session index.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Button {
            accountManager.setAuthUser(
              account,
              authuser: max(account.authuser - 1, 0)
            )
          } label: {
            Image(systemName: "minus")
              .frame(width: 12, height: 12)
          }
          .disabled(account.authuser <= 0)
          .eventHoverEffect()

          Button {
          } label: {
            Text(account.authuser, format: .number)

          }
          .frame(width: 24)
          .buttonStyle(.borderless)

          Button {
            accountManager.setAuthUser(
              account,
              authuser: min(account.authuser + 1, 99)
            )
          } label: {
            Image(systemName: "plus")
              .frame(width: 12, height: 12)
          }
          .disabled(account.authuser >= 99)
          .eventHoverEffect()
        }

      }.padding(.vertical, 2)
    }

    private func grantEditPermission() {
      isReauthorizing = true
      Task {
        defer { isReauthorizing = false }
        _ = await accountManager.upgrade(account)
        await eventManager.sync()
      }
    }
  }

  private struct AccountCalendarSettingsRow: View {
    let account: GoogleAccount
    @Environment(GoogleAccountManager.self) private var accountManager

    var body: some View {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("All Calendars")
            .foregroundStyle(account.isVisible ? .primary : .secondary)
          Text("Toggle all calendars.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button {
          accountManager.toggleVisibility(account)
        } label: {
          Image(systemName: account.isVisible ? "eye" : "eye.slash")
            .frame(width: 12, height: 12)
            .foregroundStyle(account.isVisible ? .primary : .secondary)
        }
        .eventHoverEffect()
      }
    }
  }

  /// A single account with expandable calendar toggles.
  private struct CalendarSettingsRow: View {
    let account: GoogleAccount
    let calendar: GoogleCalendar

    @Environment(GoogleCalendarManager.self) private var calendarManager

    var body: some View {
      HStack(alignment: .center) {

        Circle()
          .foregroundStyle(Color(hex: calendar.backgroundColor))
          .frame(width: 12, height: 12)
          .padding(.horizontal, 2)

        Text(calendar.displayName)
          .foregroundStyle(
            account.isVisible && calendar.isVisible ? .primary : .secondary
          )

        Spacer()

        Button {
          calendarManager.toggleVisibility(calendar)
        } label: {
          Image(
            systemName: account.isVisible && calendar.isVisible
              ? "eye" : "eye.slash"
          )
          .frame(width: 12, height: 12)
          .foregroundStyle(
            account.isVisible && calendar.isVisible ? .primary : .secondary
          )
        }
        .eventHoverEffect()

      }
      .padding(.vertical, 2)
      .padding(.leading, 6)
    }
  }

  private struct AccountRemove: View {

    let account: GoogleAccount
    @Environment(GoogleAccountManager.self) private var accountManager
    @Environment(GoogleCalendarManager.self) private var calendarManager
    @Environment(GoogleCalendarEventManager.self) private var eventManager
    @State private var showDeleteConfirmation = false
    @State private var isExpanded = false
    @State private var isReauthorizing = false

    private var accountCalendars: [GoogleCalendar] {
      calendarManager.forAccount(account.accountId)
        .sorted {
          $0.summary.localizedCaseInsensitiveCompare($1.summary)
            == .orderedAscending
        }
    }

    var body: some View {
      Button(role: .destructive) {
      } label: {

        HStack(spacing: 4) {
          Text("Remove")
        }
        .frame(maxWidth: .infinity, alignment: .center)
      }
      .buttonStyle(.borderless)
      .foregroundStyle(.red)
      .confirmationDialog(
        "Remove \(account.email)?",
        isPresented: $showDeleteConfirmation,
        titleVisibility: .visible
      ) {
        Button("Remove Account", role: .destructive) {
          Task {
            eventManager.logout(accountId: account.accountId)
            calendarManager.logout(accountId: account.accountId)
            await accountManager.logout(account)
          }
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This will remove the account and all its calendars and events.")
      }
    }

  }

  private struct AccountAdd: View {
    @Environment(GoogleAccountManager.self) private var accountManager
    @Environment(GoogleCalendarManager.self) private var calendarManager
    @Environment(GoogleCalendarEventManager.self) private var eventManager

    var body: some View {
      Button {
        Task {
          guard await accountManager.upsert() != nil
          else { return }
          await eventManager.sync()
        }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "plus")
          Text("Add Account")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)

      }.buttonStyle(.borderless)
    }
  }

}
