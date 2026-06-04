import AppKit
import SwiftData
import SwiftUI
import os

/// Entry point for Callisto — menu bar only, no Dock icon, no main window.
///
/// Constructs a single ``GoogleCalendarEventManager`` which owns the account
/// and calendar managers it depends on. The trio is injected into the SwiftUI
/// environment for views to consume.
@main
struct CalendarApp: App {

  @State private var userSettings: UserSettings
  @State private var eventManager: GoogleCalendarEventManager
  @State private var syncScheduler = SyncScheduler()
  @State private var minuteTicker = MinuteScheduler()
  @State private var rightClick = MenuBarRightClick()
  @State private var appUpdater = AppUpdater()
  @State private var loginItemService = LoginItemService()

  private let container: ModelContainer

  init() {
    let schema = Schema([
      GoogleAccount.self,
      GoogleCalendar.self,
      GoogleCalendarEvent.self,
      EventAttendee.self,
      EventAttachment.self,
      EventReminder.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    let container: ModelContainer
    do {
      container = try ModelContainer(for: schema, configurations: [config])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
    self.container = container

    _userSettings = State(
      initialValue: UserSettings(store: UserDefaults.standard)
    )
    _eventManager = State(
      initialValue: GoogleCalendarEventManager(container: container)
    )
  }

  var body: some Scene {
    MenuBarExtra {
      Popover()
        .openWindowsAction()
        .environment(eventManager)
        .environment(eventManager.accounts)
        .environment(eventManager.calendars)
        .environment(userSettings)
        .environment(minuteTicker)
        .modelContainer(container)
        .task {
          minuteTicker.start()
          startScheduler()
        }
        .onChange(of: userSettings.refreshIntervalMinutes) { _, _ in
          startScheduler()
        }
    } label: {
      MenuBarLabelContainer(
        event: eventManager.next(),
        eventManager: eventManager,
        rightClick: rightClick,
        appUpdater: appUpdater
      )
      .environment(minuteTicker)
    }
    .menuBarExtraStyle(.window)

    Window("\(AppInfo.displayName) Settings", id: AppWindow.settings.rawValue) {
      SettingsWindow()
        .openWindowsAction()
        .environment(eventManager)
        .environment(eventManager.accounts)
        .environment(eventManager.calendars)
        .environment(userSettings)
        .environment(minuteTicker)
        .environment(appUpdater)
        .environment(loginItemService)
        .modelContainer(container)
    }
    .windowResizability(.contentSize)
    .defaultPosition(.center)
  }

  private func startScheduler() {
    let interval = userSettings.refreshIntervalMinutes
    Logger.shared.info("Starting sync scheduler with interval \(interval) min")
    syncScheduler.start(intervalMinutes: interval) { [eventManager] in
      await eventManager.sync()
      eventManager.prune()
    }
  }
}

private struct MenuBarLabelContainer: View {
  let event: GoogleCalendarEvent?
  let eventManager: GoogleCalendarEventManager
  let rightClick: MenuBarRightClick
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    MenuBarLabel(event: event)
      .task {
        rightClick.start(
          eventManager: eventManager,
          accountManager: eventManager.accounts,
          openSettings: {
            NSApp.keyWindow?.close()
            openWindow(id: AppWindow.settings.rawValue)
            NSApp.activate(ignoringOtherApps: true)
          }
        )
      }
  }
}
