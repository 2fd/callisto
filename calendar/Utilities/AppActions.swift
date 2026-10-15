import AppKit
import SwiftUI

/// Windows defined by the app — the single source of truth for window IDs.
enum AppWindow: String {
    case settings
}

/// Opens an ``AppWindow``.
///
/// Injected by ``AppDelegate``, which owns the windows. Views call
/// `openWindows(.settings)` and stay unaware of AppKit.
struct OpenWindowsAction {
    fileprivate let handler: @MainActor (AppWindow) -> Void

    @MainActor
    func callAsFunction(_ window: AppWindow) {
        handler(window)
    }

    init(_ handler: @escaping @MainActor (AppWindow) -> Void) {
        self.handler = handler
    }
}

extension EnvironmentValues {
    @Entry var openWindows: OpenWindowsAction = OpenWindowsAction { _ in }
}

extension Notification.Name {
    /// Posted when something finishes an action that should close the menu bar
    /// panel — following an event link, opening settings, pressing Escape.
    static let dismissMenuBarPanel = Notification.Name(
        "\(Constants.subsystem).dismissMenuBarPanel"
    )

    /// Posted when the user dismisses the meeting alert itself — its Dismiss
    /// button or Escape — rather than acting on one of its events.
    static let dismissMeetingAlert = Notification.Name(
        "\(Constants.subsystem).dismissMeetingAlert"
    )
}

/// `userInfo` key of `.dismissMenuBarPanel`: the `compositeId` of the event
/// the user acted on, if any. Acting on an event the meeting alert shows
/// counts as using that alert, wherever the action came from.
let dismissedEventIdKey = "eventId"

/// Closes the menu bar panel if it is open.
///
/// The panel is an ``MenuBarPanel``, not the key window, so callers must not
/// reach for `NSApp.keyWindow` — that would close the settings window whenever
/// the panel was not focused.
///
/// Pass the event when the action was on one — joining it, opening it — so a
/// meeting alert showing that event is put away too.
func dismissMenuBarPanel(actingOn event: GoogleCalendarEvent? = nil) {
    let userInfo = event.map { [dismissedEventIdKey: $0.compositeId] }
    NotificationCenter.default.post(name: .dismissMenuBarPanel, object: nil, userInfo: userInfo)
}

/// Puts the meeting alert away without acting on any of its events.
func dismissMeetingAlert() {
    NotificationCenter.default.post(name: .dismissMeetingAlert, object: nil)
}
