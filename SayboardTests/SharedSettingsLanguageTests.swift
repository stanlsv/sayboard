import Foundation
import Testing

@Suite("SharedSettings preferred languages")
struct SharedSettingsLanguageTests {

  @Test
  func `default is empty for any variant`() throws {
    let settings = try Self.makeSettings()
    #expect(settings.preferredLanguages(for: .whisperSmall).isEmpty)
    #expect(settings.preferredLanguages(for: .whisperBase).isEmpty)
    #expect(settings.preferredLanguages(for: .parakeetV3).isEmpty)
  }

  @Test
  func `round-trip a multi-language set`() throws {
    let settings = try Self.makeSettings()
    settings.setPreferredLanguages(["en", "ru", "cs"], for: .whisperSmall)
    #expect(settings.preferredLanguages(for: .whisperSmall) == ["en", "ru", "cs"])
  }

  @Test
  func `setting empty removes the entry`() throws {
    let suiteName = Self.uniqueSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { Self.cleanup(suiteName: suiteName) }
    let settings = SharedSettings(defaults: defaults)

    settings.setPreferredLanguages(["en"], for: .whisperSmall)
    #expect(defaults.data(forKey: SharedKey.preferredLanguagesPerVariant) != nil)

    settings.setPreferredLanguages([], for: .whisperSmall)
    #expect(defaults.data(forKey: SharedKey.preferredLanguagesPerVariant) == nil)
  }

  @Test
  func `per-variant isolation`() throws {
    let settings = try Self.makeSettings()
    settings.setPreferredLanguages(["en"], for: .whisperSmall)
    settings.setPreferredLanguages(["ru", "uk"], for: .whisperBase)

    #expect(settings.preferredLanguages(for: .whisperSmall) == ["en"])
    #expect(settings.preferredLanguages(for: .whisperBase) == ["ru", "uk"])
    #expect(settings.preferredLanguages(for: .whisperTiny).isEmpty)
  }

  @Test
  func `overwriting replaces the set`() throws {
    let settings = try Self.makeSettings()
    settings.setPreferredLanguages(["en", "ru"], for: .whisperSmall)
    settings.setPreferredLanguages(["de"], for: .whisperSmall)
    #expect(settings.preferredLanguages(for: .whisperSmall) == ["de"])
  }

  private static func makeSettings() throws -> SharedSettings {
    let suiteName = self.uniqueSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return SharedSettings(defaults: defaults)
  }

  private static func uniqueSuiteName() -> String {
    "app.sayboard.tests.\(UUID().uuidString)"
  }

  private static func cleanup(suiteName: String) {
    UserDefaults().removePersistentDomain(forName: suiteName)
  }
}
