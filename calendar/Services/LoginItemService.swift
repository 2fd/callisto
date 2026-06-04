import Foundation
import Observation
import ServiceManagement

protocol LoginItemControlling {
  var status: SMAppService.Status { get }
  func register() throws
  func unregister() throws
}

struct MainAppLoginItemController: LoginItemControlling {
  var status: SMAppService.Status {
    SMAppService.mainApp.status
  }

  func register() throws {
    try SMAppService.mainApp.register()
  }

  func unregister() throws {
    try SMAppService.mainApp.unregister()
  }
}

enum LoginItemStatus: Equatable {
  case enabled
  case disabled
  case requiresApproval
  case unavailable

  init(_ status: SMAppService.Status) {
    switch status {
    case .enabled:
      self = .enabled
    case .notRegistered:
      self = .disabled
    case .requiresApproval:
      self = .requiresApproval
    case .notFound:
      self = .unavailable
    @unknown default:
      self = .unavailable
    }
  }
}

@MainActor @Observable
final class LoginItemService {
  private let controller: LoginItemControlling

  private(set) var status: LoginItemStatus = .disabled
  private(set) var errorMessage: String?

  init() {
    self.controller = MainAppLoginItemController()
    refresh()
  }

  init(controller: LoginItemControlling) {
    self.controller = controller
    refresh()
  }

  var isEnabled: Bool {
    status == .enabled
  }

  var canToggle: Bool {
    status != .unavailable
  }

  var statusMessage: String? {
    switch status {
    case .enabled, .disabled:
      return nil
    case .requiresApproval:
      return "Approve Open at Login in System Settings."
    case .unavailable:
      return "Open at Login is unavailable for this app."
    }
  }

  func refresh() {
    updateStatus()
    errorMessage = nil
  }

  func setEnabled(_ enabled: Bool) {
    errorMessage = nil

    do {
      let currentStatus = controller.status

      if enabled {
        if currentStatus == .notRegistered || currentStatus == .notFound {
          try controller.register()
        }
      } else if currentStatus == .enabled || currentStatus == .requiresApproval {
        try controller.unregister()
      }

      updateStatus()
    } catch {
      updateStatus()
      errorMessage = "Could not update Open at Login: \(error.localizedDescription)"
    }
  }

  private func updateStatus() {
    status = LoginItemStatus(controller.status)
  }
}
