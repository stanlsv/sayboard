import Foundation
import Testing

@Suite("SharedSettings entitlement state")
struct SharedSettingsEntitlementTests {

  @Test
  func `nothing is verified and nothing is spent on a fresh install`() throws {
    let settings = try Self.makeSettings()
    #expect(settings.entitlementStatus == .unknown)
    #expect(settings.freeWordsUsed == 0)
  }

  @Test
  func `the environment that verified the status round-trips`() throws {
    let settings = try Self.makeSettings()
    #expect(settings.entitlementEnvironment == nil)
    settings.entitlementEnvironment = Self.environment
    #expect(settings.entitlementEnvironment == Self.environment)
  }

  @Test
  func `the verified status round-trips`() throws {
    let settings = try Self.makeSettings()
    settings.entitlementStatus = .unlocked
    #expect(settings.entitlementStatus == .unlocked)
    settings.entitlementStatus = .free
    #expect(settings.entitlementStatus == .free)
  }

  @Test
  func `a free install is charged for every dictation`() throws {
    let settings = try Self.makeSettings(status: .free)
    settings.chargeFreeWords(Self.firstDictation, storeBuild: true)
    settings.chargeFreeWords(Self.secondDictation, storeBuild: true)
    #expect(settings.freeWordsUsed == Self.firstDictation + Self.secondDictation)
  }

  @Test
  func `an install StoreKit has not verified yet is charged too`() throws {
    let settings = try Self.makeSettings(status: .unknown)
    settings.chargeFreeWords(Self.firstDictation, storeBuild: true)
    #expect(settings.freeWordsUsed == Self.firstDictation)
  }

  @Test
  func `a dictation with no words changes nothing`() throws {
    let settings = try Self.makeSettings(status: .free)
    settings.chargeFreeWords(Self.firstDictation, storeBuild: true)
    settings.chargeFreeWords(0, storeBuild: true)
    #expect(settings.freeWordsUsed == Self.firstDictation)
  }

  @Test
  func `a buyer is never charged, and their words are never counted`() throws {
    let settings = try Self.makeSettings(status: .unlocked)
    var wasCounted = false
    settings.chargeFreeWords(
      {
        wasCounted = true
        return Self.firstDictation
      }(),
      storeBuild: true,
    )
    #expect(settings.freeWordsUsed == 0)
    #expect(!wasCounted)
  }

  @Test
  func `a build outside the AppStore configuration is never charged, and its words are never counted`() throws {
    let settings = try Self.makeSettings(status: .free)
    var wasCounted = false
    settings.chargeFreeWords(
      {
        wasCounted = true
        return Self.firstDictation
      }(),
      storeBuild: false,
    )
    #expect(settings.freeWordsUsed == 0)
    #expect(!wasCounted)
  }

  @Test
  func `a build outside the AppStore configuration never locks, even with the allowance spent`() throws {
    let settings = try Self.makeSettings(status: .free)
    settings.chargeFreeWords(Self.wholeAllowance, storeBuild: true)
    #expect(settings.dictationAllowance.isExhausted)
    #expect(!settings.isDictationLocked)
  }

  @Test
  func `the allowance reflects the stored state`() throws {
    let settings = try Self.makeSettings(status: .free)
    settings.chargeFreeWords(Self.firstDictation, storeBuild: true)
    #expect(settings.dictationAllowance == DictationAllowance(status: .free, wordsUsed: Self.firstDictation))
  }

  @Test
  func `an unreadable stored status falls back to unknown`() throws {
    let suiteName = Self.uniqueSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { Self.cleanup(suiteName: suiteName) }
    defaults.set("lifetime", forKey: SharedKey.entitlementStatus)
    #expect(SharedSettings(defaults: defaults).entitlementStatus == .unknown)
  }

  private static let firstDictation = 42
  private static let secondDictation = 17
  private static let wholeAllowance = 3_000
  private static let environment = "Production"

  private static func makeSettings(status: EntitlementStatus? = nil) throws -> SharedSettings {
    let suiteName = self.uniqueSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let settings = SharedSettings(defaults: defaults)
    if let status {
      settings.entitlementStatus = status
    }
    return settings
  }

  private static func uniqueSuiteName() -> String {
    "app.sayboard.tests.\(UUID().uuidString)"
  }

  private static func cleanup(suiteName: String) {
    UserDefaults().removePersistentDomain(forName: suiteName)
  }
}
