import Foundation
import Testing

@Suite("SharedSettings declined LLM upgrades")
struct SharedSettingsLLMUpgradeTests {

  @Test
  func `default is empty`() throws {
    let settings = try Self.makeSettings()
    #expect(settings.declinedLLMUpgrades.isEmpty)
  }

  @Test
  func `round-trip a set of successors`() throws {
    let settings = try Self.makeSettings()
    settings.declinedLLMUpgrades = [.qwen35Small, .gemma3OneQAT]
    #expect(settings.declinedLLMUpgrades == [.qwen35Small, .gemma3OneQAT])
  }

  @Test
  func `emptying removes the entry`() throws {
    let suiteName = Self.uniqueSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { Self.cleanup(suiteName: suiteName) }
    let settings = SharedSettings(defaults: defaults)

    settings.declinedLLMUpgrades = [.qwen35Small]
    #expect(defaults.stringArray(forKey: SharedKey.declinedLLMUpgrades) != nil)

    settings.declinedLLMUpgrades = []
    #expect(defaults.stringArray(forKey: SharedKey.declinedLLMUpgrades) == nil)
  }

  @Test
  func `a rawValue no longer in the catalog is dropped`() throws {
    let suiteName = Self.uniqueSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { Self.cleanup(suiteName: suiteName) }
    let settings = SharedSettings(defaults: defaults)

    defaults.set(["qwen35-0.8b-q4km", "a-model-that-was-removed"], forKey: SharedKey.declinedLLMUpgrades)
    #expect(settings.declinedLLMUpgrades == [.qwen35Small])
  }

  @Test
  func `declining one successor leaves the others upgradable`() throws {
    let settings = try Self.makeSettings()
    settings.declinedLLMUpgrades = [.qwen35Small]
    #expect(settings.declinedLLMUpgrades.contains(.qwen35Small))
    #expect(!settings.declinedLLMUpgrades.contains(.qwen35Large))
    #expect(!settings.declinedLLMUpgrades.contains(.gemma3OneQAT))
  }

  @Test
  func `every successor names exactly one predecessor`() {
    let successors = LLMModelVariant.allCases.compactMap(\.successor)
    #expect(!successors.isEmpty)
    for successor in successors {
      let predecessors = LLMModelVariant.allCases.filter { $0.successor == successor }
      #expect(predecessors.count == 1)
    }
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
