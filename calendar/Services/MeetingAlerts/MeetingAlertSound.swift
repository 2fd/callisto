import AudioToolbox
import os

/// The sound of the menu bar popup. Native notifications carry their own.
///
/// Played as a system sound rather than through `NSSound`, so it follows the
/// alert volume and the "Play sound effects through" device in System Settings,
/// as a notification's sound does. A heads-up arrives while a meeting is
/// underway: it must not play through the call at full output volume.
///
/// The file is read from `/System/Library/Sounds`, which the sandbox allows;
/// Apple's sounds may be referenced but not copied into the bundle.
enum MeetingAlertSound {

  /// Registered on first use and kept for the life of the app; `nil` when the
  /// file could not be registered, which leaves the popup silent.
  private static let soundID: SystemSoundID? = {
    var id: SystemSoundID = 0
    let status = AudioServicesCreateSystemSoundID(
      Constants.meetingAlertSoundURL as CFURL,
      &id
    )
    guard status == kAudioServicesNoError else {
      Logger.shared.error("Could not load the meeting alert sound: \(status, privacy: .public)")
      return nil
    }
    return id
  }()

  static func play() {
    guard let soundID else { return }
    AudioServicesPlaySystemSound(soundID)
  }
}
