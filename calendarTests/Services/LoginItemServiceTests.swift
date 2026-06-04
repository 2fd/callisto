import ServiceManagement
import Testing
@testable import calendar

@Suite("LoginItemService")
@MainActor
struct LoginItemServiceTests {
  @Test func notRegisteredMapsToDisabled() {
    let controller = FakeLoginItemController(status: .notRegistered)
    let service = LoginItemService(controller: controller)

    #expect(service.status == .disabled)
    #expect(service.isEnabled == false)
    #expect(service.statusMessage == nil)
  }

  @Test func enabledMapsToEnabled() {
    let controller = FakeLoginItemController(status: .enabled)
    let service = LoginItemService(controller: controller)

    #expect(service.status == .enabled)
    #expect(service.isEnabled == true)
    #expect(service.statusMessage == nil)
  }

  @Test func registerSuccessRefreshesState() {
    let controller = FakeLoginItemController(status: .notRegistered)
    let service = LoginItemService(controller: controller)

    service.setEnabled(true)

    #expect(controller.registerCalls == 1)
    #expect(controller.unregisterCalls == 0)
    #expect(service.status == .enabled)
    #expect(service.isEnabled == true)
    #expect(service.errorMessage == nil)
  }

  @Test func unregisterSuccessRefreshesState() {
    let controller = FakeLoginItemController(status: .enabled)
    let service = LoginItemService(controller: controller)

    service.setEnabled(false)

    #expect(controller.registerCalls == 0)
    #expect(controller.unregisterCalls == 1)
    #expect(service.status == .disabled)
    #expect(service.isEnabled == false)
    #expect(service.errorMessage == nil)
  }

  @Test func registerFailurePreservesReadableError() {
    let controller = FakeLoginItemController(
      status: .notRegistered,
      registerError: FakeLoginItemError.failed
    )
    let service = LoginItemService(controller: controller)

    service.setEnabled(true)

    #expect(controller.registerCalls == 1)
    #expect(service.status == .disabled)
    #expect(service.isEnabled == false)
    #expect(service.errorMessage?.contains("Could not update Open at Login") == true)
  }

  @Test func unregisterFailurePreservesReadableError() {
    let controller = FakeLoginItemController(
      status: .enabled,
      unregisterError: FakeLoginItemError.failed
    )
    let service = LoginItemService(controller: controller)

    service.setEnabled(false)

    #expect(controller.unregisterCalls == 1)
    #expect(service.status == .enabled)
    #expect(service.isEnabled == true)
    #expect(service.errorMessage?.contains("Could not update Open at Login") == true)
  }

  @Test func requiresApprovalIsNotFullyEnabled() {
    let controller = FakeLoginItemController(status: .requiresApproval)
    let service = LoginItemService(controller: controller)

    #expect(service.status == .requiresApproval)
    #expect(service.isEnabled == false)
    #expect(service.statusMessage == "Approve Open at Login in System Settings.")
  }

  @Test func unavailableCannotBeToggled() {
    let controller = FakeLoginItemController(status: .notFound)
    let service = LoginItemService(controller: controller)

    #expect(service.status == .unavailable)
    #expect(service.isEnabled == false)
    #expect(service.canToggle == false)
    #expect(service.statusMessage == "Open at Login is unavailable for this app.")
  }
}

private final class FakeLoginItemController: LoginItemControlling {
  var status: SMAppService.Status
  var registerError: Error?
  var unregisterError: Error?
  private(set) var registerCalls = 0
  private(set) var unregisterCalls = 0

  init(
    status: SMAppService.Status,
    registerError: Error? = nil,
    unregisterError: Error? = nil
  ) {
    self.status = status
    self.registerError = registerError
    self.unregisterError = unregisterError
  }

  func register() throws {
    registerCalls += 1
    if let registerError {
      throw registerError
    }
    status = .enabled
  }

  func unregister() throws {
    unregisterCalls += 1
    if let unregisterError {
      throw unregisterError
    }
    status = .notRegistered
  }
}

private enum FakeLoginItemError: LocalizedError {
  case failed

  var errorDescription: String? {
    "Fake login item failure"
  }
}
