import AppKit
import Observation
import SwiftData
import SwiftUI
import os

/// Entry point for Callisto — menu bar only, no Dock icon, no main window.
///
/// The app is AppKit-driven rather than a SwiftUI `App`. `MenuBarExtra` renders
/// its label as a template image, which flattened the per-provider conference
/// colours to the menu bar tint, and it hid its `NSStatusItem`. Owning the
/// status item means owning the panel, and a panel hosted outside the scene
/// graph cannot reach `@Environment(\.openWindow)` — so the settings window is
/// ours too. See ``MenuBarController`` and ``SettingsWindowController``.
///
/// Construction stays a single chain: one `ModelContainer` →
/// ``GoogleCalendarEventManager`` builds ``GoogleCalendarManager`` builds
/// ``GoogleAccountManager``.
///
/// Installed by `main.swift`, which explains why the entry point is explicit.
final class AppDelegate: NSObject, NSApplicationDelegate {

  private var container: ModelContainer!
  private var userSettings: UserSettings!
  private var eventManager: GoogleCalendarEventManager!
  private var appUpdater: AppUpdater!

  private let syncScheduler = SyncScheduler()
  private let minuteTicker = MinuteScheduler()

  private var menuBar: MenuBarController!
  private var settingsWindow: SettingsWindowController!

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Redundant with LSUIElement, but makes the policy explicit and survives a
    // plist edit.
    NSApp.setActivationPolicy(.accessory)
    NSApp.mainMenu = makeMainMenu()

    let schema = Schema([
      GoogleAccount.self,
      GoogleCalendar.self,
      GoogleCalendarEvent.self,
      EventAttendee.self,
      EventAttachment.self,
      EventReminder.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    do {
      container = try ModelContainer(for: schema, configurations: [config])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }

    userSettings = UserSettings(store: UserDefaults.standard)
    eventManager = GoogleCalendarEventManager(container: container)
    appUpdater = AppUpdater()

    settingsWindow = SettingsWindowController(rootView: inject(SettingsWindow()))

    menuBar = MenuBarController(
      label: inject(MenuBarStatusLabel()),
      content: inject(Popover()),
      contextMenu: { [unowned self] in
        makeMenuBarContextMenu(
          eventManager: eventManager,
          accountManager: eventManager.accounts,
          openSettings: { [unowned self] in openSettings() }
        )
      }
    )

    minuteTicker.start()
    startScheduler()
    observeRefreshInterval()
  }

  func applicationWillTerminate(_ notification: Notification) {
    syncScheduler.stop()
    minuteTicker.stop()
  }

  /// Receives the OAuth redirect.
  ///
  /// Consent runs in the user's browser (``AuthorizationSession`` explains
  /// why), so the redirect arrives here through the scheme declared in
  /// `Info.plist` rather than being captured in-process. Nothing else in the
  /// app registers a URL scheme.
  func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      // Never log the URL itself — it carries the authorization code.
      guard eventManager?.accounts.handleAuthorizationCallback(url) == true
      else {
        Logger.shared.error(
          "Ignored a \(url.scheme ?? "schemeless", privacy: .public) URL matching no pending sign-in"
        )
        continue
      }
      return
    }
  }

  // MARK: - Wiring

  /// Injects the manager chain and app-level actions into a view tree.
  ///
  /// Both the panel and the settings window are hosted separately, so each needs
  /// the environment applied at its own root.
  private func inject(_ view: some View) -> AnyView {
    AnyView(
      view
        .environment(eventManager)
        .environment(eventManager.accounts)
        .environment(eventManager.calendars)
        .environment(userSettings)
        .environment(minuteTicker)
        .environment(appUpdater)
        .environment(
          \.openWindows,
          OpenWindowsAction { [unowned self] window in
            switch window {
            case .settings: openSettings()
            }
          }
        )
        .modelContainer(container)
    )
  }

  private func openSettings() {
    dismissMenuBarPanel()
    settingsWindow.show()
  }

  private func startScheduler() {
    let interval = userSettings.refreshIntervalMinutes
    Logger.shared.info("Starting sync scheduler with interval \(interval) min")
    syncScheduler.start(intervalMinutes: interval) { [eventManager] in
      await eventManager?.sync()
      eventManager?.prune()
    }
  }

  /// Restarts the scheduler when the user changes the refresh interval.
  ///
  /// Replaces the `onChange(of:)` the `MenuBarExtra` scene used to carry.
  /// `withObservationTracking` fires once, so it re-arms itself.
  private func observeRefreshInterval() {
    withObservationTracking {
      _ = userSettings.refreshIntervalMinutes
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.startScheduler()
        self?.observeRefreshInterval()
      }
    }
  }

  // MARK: - Main menu

  /// A minimal main menu.
  ///
  /// An accessory app never displays one, but without it the key equivalents it
  /// carries — ⌘Q, and clipboard commands inside the settings window and
  /// Sparkle's dialogs — do not work at all.
  private func makeMainMenu() -> NSMenu {
    let mainMenu = NSMenu()

    let appItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(
      withTitle: "Quit \(AppInfo.displayName)",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)

    let editItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(
      withTitle: "Undo",
      action: Selector(("undo:")),
      keyEquivalent: "z"
    )
    editMenu.addItem(
      withTitle: "Redo",
      action: Selector(("redo:")),
      keyEquivalent: "Z"
    )
    editMenu.addItem(.separator())
    editMenu.addItem(
      withTitle: "Cut",
      action: #selector(NSText.cut(_:)),
      keyEquivalent: "x"
    )
    editMenu.addItem(
      withTitle: "Copy",
      action: #selector(NSText.copy(_:)),
      keyEquivalent: "c"
    )
    editMenu.addItem(
      withTitle: "Paste",
      action: #selector(NSText.paste(_:)),
      keyEquivalent: "v"
    )
    editMenu.addItem(
      withTitle: "Select All",
      action: #selector(NSText.selectAll(_:)),
      keyEquivalent: "a"
    )
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)

    return mainMenu
  }
}
