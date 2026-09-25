import Foundation
import Testing

@Suite("The keyboard in the onboarding practice field: its mic arrow and the app's host check")
struct SharedSettingsMicHintTests {

  @Test
  func `the arrow shows in the app's own practice field`() throws {
    let settings = try Self.makeSettings()
    settings.onboardingPracticeProcessID = Self.appPid
    #expect(settings.showsMicHint(hostProcessID: Self.appPid))
  }

  @Test
  func `another app beside the practice gets no arrow`() throws {
    let settings = try Self.makeSettings()
    settings.onboardingPracticeProcessID = Self.appPid
    #expect(!settings.showsMicHint(hostProcessID: Self.otherAppPid))
  }

  @Test
  func `a host that cannot be read is taken to be the app`() throws {
    let settings = try Self.makeSettings()
    settings.onboardingPracticeProcessID = Self.appPid
    #expect(settings.showsMicHint(hostProcessID: nil))
  }

  @Test
  func `there is no arrow outside the practice`() throws {
    let settings = try Self.makeSettings()
    #expect(!settings.showsMicHint(hostProcessID: Self.appPid))
  }

  @Test
  func `a practice that ended leaves no arrow behind`() throws {
    let settings = try Self.makeSettings()
    settings.onboardingPracticeProcessID = Self.appPid
    settings.onboardingPracticeProcessID = nil
    #expect(!settings.showsMicHint(hostProcessID: nil))
  }

  @Test
  func `a dismissed arrow never comes back`() throws {
    let settings = try Self.makeSettings()
    settings.isMicHintDismissed = true
    settings.onboardingPracticeProcessID = Self.appPid
    #expect(!settings.showsMicHint(hostProcessID: Self.appPid))
  }

  @Test
  func `the practice field is still recognized after the arrow is dismissed`() throws {
    let settings = try Self.makeSettings()
    settings.onboardingPracticeProcessID = Self.appPid
    settings.isMicHintDismissed = true
    #expect(settings.isOnboardingPracticeHost(Self.appPid))
  }

  @Test
  func `another app is not the practice field`() throws {
    let settings = try Self.makeSettings()
    settings.onboardingPracticeProcessID = Self.appPid
    #expect(!settings.isOnboardingPracticeHost(Self.otherAppPid))
  }

  @Test
  func `nothing is the practice field outside the practice`() throws {
    let settings = try Self.makeSettings()
    #expect(!settings.isOnboardingPracticeHost(nil))
  }

  @Test
  func `a practice a crash left marked stops counting`() throws {
    let settings = try Self.makeSettings()
    settings.onboardingPracticeProcessID = Self.appPid
    #expect(!settings.isOnboardingPracticeHost(nil, now: CFAbsoluteTimeGetCurrent() + Self.afterTheMarkExpires))
  }

  @Test
  func `a practice nobody rushes still counts`() throws {
    let settings = try Self.makeSettings()
    settings.onboardingPracticeProcessID = Self.appPid
    #expect(settings.isOnboardingPracticeHost(Self.appPid, now: CFAbsoluteTimeGetCurrent() + Self.beforeTheMarkExpires))
  }

  private static let appPid = 412
  private static let otherAppPid = 97
  private static let afterTheMarkExpires: TimeInterval = 31 * 60
  private static let beforeTheMarkExpires: TimeInterval = 29 * 60

  private static func makeSettings() throws -> SharedSettings {
    let suiteName = "app.sayboard.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return SharedSettings(defaults: defaults)
  }
}
