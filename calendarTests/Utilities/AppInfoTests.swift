import Testing
@testable import calendar

@Suite("AppInfo")
struct AppInfoTests {
  @Test func displayNameUsesBundleDisplayName() {
    let name = AppInfo.displayName(infoDictionary: [
      "CFBundleDisplayName": "Callisto Nightly",
      "CFBundleName": "Callisto",
    ])

    #expect(name == "Callisto Nightly")
  }

  @Test func displayNameFallsBackToBundleName() {
    let name = AppInfo.displayName(infoDictionary: [
      "CFBundleName": "Callisto",
    ])

    #expect(name == "Callisto")
  }

  @Test func displayNameFallsBackToCallisto() {
    let name = AppInfo.displayName(infoDictionary: [:])

    #expect(name == "Callisto")
  }
}
