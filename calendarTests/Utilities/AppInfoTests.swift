import Testing
@testable import calendar

@Suite("AppInfo")
struct AppInfoTests {
  @Test func isNightlyBuildReflectsCompilationCondition() {
    #expect(AppInfo.isNightlyBuild(nightlyCompilationCondition: true))
    #expect(!AppInfo.isNightlyBuild(nightlyCompilationCondition: false))
  }

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

  @Test func versionUsesBundleShortVersion() {
    let version = AppInfo.version(infoDictionary: [
      "CFBundleShortVersionString": "1.2.3"
    ])

    #expect(version == "1.2.3")
  }

  @Test func versionFallsBackToUnknown() {
    let version = AppInfo.version(infoDictionary: [
      "CFBundleShortVersionString": ""
    ])

    #expect(version == "Unknown")
  }

  @Test func buildIDUsesBundleVersion() {
    let buildID = AppInfo.buildID(infoDictionary: [
      "CFBundleVersion": "20260603123456"
    ])

    #expect(buildID == "20260603123456")
  }

  @Test func buildIDFallsBackToUnknown() {
    let buildID = AppInfo.buildID(infoDictionary: [:])

    #expect(buildID == "Unknown")
  }
}
