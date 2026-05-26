import Sparkle
import SwiftUI

/// Owns Sparkle's standard updater controller and exposes user-triggered update checking.
///
/// Initialized once at app level and kept alive for the lifetime of the process.
@MainActor @Observable
final class AppUpdater {

  private let updaterController: SPUStandardUpdaterController

  init() {
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )
  }

  func checkForUpdates() {
    updaterController.checkForUpdates(nil)
  }
}
