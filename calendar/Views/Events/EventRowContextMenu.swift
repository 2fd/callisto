import AppKit
import SwiftUI
import os

/// Right-click context menu for an ``EventRow``.
///
/// For recurring events, each mutation action (RSVP / delete) is a submenu
/// exposing "This event" and "This and following" scopes. Non-recurring
/// events get flat buttons that apply immediately.
struct EventRowContextMenu: View {
  let entry: EventEntry

  @Environment(GoogleCalendarEventManager.self) private var eventManager
  @Environment(GoogleAccountManager.self) private var accountManager

  private var event: GoogleCalendarEvent { entry.event }
  private var account: GoogleAccount { entry.account }

  var body: some View {
    openSection
    Divider()
    rsvpSection
    attendeesSection
    mutationSection
  }

  // MARK: - RSVP

  @ViewBuilder
  private var rsvpSection: some View {
    if canRSVP {
      rsvpButton(title: "Accept", target: EventStatus.accepted)
      rsvpButton(title: "Maybe", target: EventStatus.tentative)
      rsvpButton(title: "Decline", target: EventStatus.declined)
      Divider()
    }
  }

  private func rsvpButton(title: String, target: String) -> some View {
    let selected = event.selfResponseStatus == target
    return scopedAction(title: title, selected: selected) { scope in
      perform {
        try await eventManager.setSelfResponse(
          event,
          to: target,
          scope: scope
        )
      }
    }
  }

  // MARK: - Open

  @ViewBuilder
  private var openSection: some View {
    if event.conferenceMeetURL(authuser: account.authuser) != nil {
      Button("Open meeting") {
        guard let url = event.conferenceMeetURL(authuser: account.authuser)
        else { return }
        NSWorkspace.shared.open(url)
        NSApp.keyWindow?.close()  
      }
    }
    Button("Open in Calendar") {
      openCalendarLink(for: event, account: account)
    }
  }

  // MARK: - Mutations

  @ViewBuilder
  private var mutationSection: some View {
    if !account.hasEventsWriteScope {
      Button("Grant edit permission…") {
        Task { _ = await accountManager.upgrade(account) }
      }
    } else if canOrganizerDelete {
      scopedAction(title: "Delete", role: .destructive) { scope in
        perform { try await eventManager.deleteEvent(event, scope: scope) }
      }
    } else {
      scopedAction(title: "Delete for me", role: .destructive) { scope in
        perform { try await eventManager.deleteForMe(event, scope: scope) }
      }
    }
  }

  // MARK: - Attendees

  @ViewBuilder
  private var attendeesSection: some View {
    let others = sortedOtherAttendees
    if !others.isEmpty {
      ForEach(others, id: \.email) { attendee in
        Button {
          copyEmail(attendee.email)
        } label: {
          if let symbol = attendeeIcon(attendee.responseStatus) {
            Label(attendeeLabel(attendee), systemImage: symbol)
              .labelStyle(.titleAndIcon)
          } else {
            Text(attendeeLabel(attendee))
          }
        }
      }
      Divider()
    }
  }

  private var sortedOtherAttendees: [EventAttendee] {
    let order: [String: Int] = [
      EventStatus.accepted: 0,
      EventStatus.needsAction: 1,
      EventStatus.tentative: 2,
      EventStatus.declined: 3,
    ]
    return event.attendees
      .filter { !$0.isSelf }
      .sorted {
        (order[$0.responseStatus] ?? 99) < (order[$1.responseStatus] ?? 99)
      }
  }

  private func attendeeLabel(_ attendee: EventAttendee) -> String {
    if let name = attendee.displayName, !name.isEmpty { return name }
    return attendee.email
  }

  private func attendeeIcon(_ status: String) -> String? {
    switch status {
    case EventStatus.accepted: return "checkmark"
    case EventStatus.tentative: return "questionmark"
    case EventStatus.declined: return "xmark"
    default: return nil
    }
  }

  private func copyEmail(_ email: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(email, forType: .string)
  }

  // MARK: - Predicates

  private var isDefaultEvent: Bool {
    event.eventType == EventType.default
  }

  private var canRSVP: Bool {
    account.hasEventsWriteScope
      && isDefaultEvent
      && event.selfAttendee != nil
      && !event.locked
  }

  private var canOrganizerDelete: Bool {
    event.organizerIsSelf || event.guestsCanModify
  }

  // MARK: - Scoped action builder

  @ViewBuilder
  private func scopedAction(
    title: String,
    selected: Bool = false,
    role: ButtonRole? = nil,
    action: @escaping (GoogleCalendarEventManager.RecurringScope) -> Void
  ) -> some View {
    if event.isRecurring {
      Menu {
        Button("This event", role: role) { action(.thisEvent) }
        Button("This and following", role: role) {
          action(.thisAndFollowing)
        }
      } label: {
        if selected {
          Label(title, systemImage: "checkmark")
            .labelStyle(.titleAndIcon)
        } else {
          Text(title)
        }
      }
    } else {
      Button(role: role) {
        action(.thisEvent)
      } label: {
        if selected {
          Label(title, systemImage: "checkmark")
            .labelStyle(.titleAndIcon)
        } else {
          Text(title)
        }
      }
      .disabled(selected)
    }
  }

  private func perform(_ block: @escaping () async throws -> Void) {
    Task {
      do {
        try await block()
      } catch {
        Logger.shared.error(
          "Event mutation failed: \(error.localizedDescription, privacy: .public)"
        )
      }
    }
  }
}
