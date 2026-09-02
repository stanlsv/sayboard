import Foundation
import Testing

@Suite("Storing a per-app writing style")
struct AppStyleStoreEntryTests {

  @Test
  func `an app with no entry has no style`() throws {
    let store = try AppStyleFixture.makeStore()
    #expect(store.style(for: AppStyleFixture.messagesBundleId) == nil)
  }

  @Test
  func `a stored entry reads back`() throws {
    let store = try AppStyleFixture.makeStore()
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.messagesBundleId, .veryCasual))
    #expect(store.style(for: AppStyleFixture.messagesBundleId) == .veryCasual)
  }

  @Test
  func `adding the same app twice replaces rather than duplicates`() throws {
    let store = try AppStyleFixture.makeStore()
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.messagesBundleId, .casual))
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.messagesBundleId, .formal))
    #expect(store.loadEntries().count == 1)
    #expect(store.style(for: AppStyleFixture.messagesBundleId) == .formal)
  }

  @Test
  func `entries are isolated per app`() throws {
    let store = try AppStyleFixture.makeStore()
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.messagesBundleId, .veryCasual))
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.mailBundleId, .formal))
    #expect(store.style(for: AppStyleFixture.messagesBundleId) == .veryCasual)
    #expect(store.style(for: AppStyleFixture.mailBundleId) == .formal)
  }

  @Test
  func `removing an entry drops its style`() throws {
    let store = try AppStyleFixture.makeStore()
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.messagesBundleId, .casual))
    store.removeEntry(bundleId: AppStyleFixture.messagesBundleId)
    #expect(store.style(for: AppStyleFixture.messagesBundleId) == nil)
  }

  @Test
  func `updating an unknown app stores nothing`() throws {
    let store = try AppStyleFixture.makeStore()
    store.updateStyle(for: AppStyleFixture.messagesBundleId, style: .veryCasual)
    #expect(store.loadEntries().isEmpty)
  }

  @Test
  func `updating a known app keeps the rest of its entry`() throws {
    let store = try AppStyleFixture.makeStore()
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.messagesBundleId, .casual))
    store.updateStyle(for: AppStyleFixture.messagesBundleId, style: .veryCasual)

    let entries = store.loadEntries()
    #expect(entries.count == 1)
    #expect(entries.first?.name == AppStyleFixture.entryName)
    #expect(entries.first?.style == .veryCasual)
  }

  @Test
  func `unreadable stored data reads as no entries`() throws {
    let suiteName = AppStyleFixture.uniqueSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(Data("not json".utf8), forKey: AppStyleFixture.appWritingStylesKey)
    #expect(AppStyleStore(defaults: defaults).loadEntries().isEmpty)
  }
}

@Suite("Resolving the style a dictation is formatted in")
struct StyleResolutionTests {

  @Test
  func `an unknown host app resolves to the default`() throws {
    let store = try AppStyleFixture.makeStore()
    #expect(store.resolvedStyle(hostBundleId: nil, defaultStyle: .casual) == .casual)
  }

  @Test
  func `a host app without an entry resolves to the default`() throws {
    let store = try AppStyleFixture.makeStore()
    let resolved = store.resolvedStyle(hostBundleId: AppStyleFixture.messagesBundleId, defaultStyle: .casual)
    #expect(resolved == .casual)
  }

  @Test
  func `a host app with an entry overrides the default`() throws {
    let store = try AppStyleFixture.makeStore()
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.messagesBundleId, .veryCasual))
    let resolved = store.resolvedStyle(hostBundleId: AppStyleFixture.messagesBundleId, defaultStyle: .formal)
    #expect(resolved == .veryCasual)
  }

  @Test
  func `entries are ignored while the host app is unknown`() throws {
    let store = try AppStyleFixture.makeStore()
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.messagesBundleId, .veryCasual))
    #expect(store.resolvedStyle(hostBundleId: nil, defaultStyle: .formal) == .formal)
  }

  @Test
  func `another app's entry does not reach this host`() throws {
    let store = try AppStyleFixture.makeStore()
    store.addEntry(AppStyleFixture.entry(AppStyleFixture.mailBundleId, .veryCasual))
    let resolved = store.resolvedStyle(hostBundleId: AppStyleFixture.messagesBundleId, defaultStyle: .formal)
    #expect(resolved == .formal)
  }

  @Test
  func `every default survives a host app with no entry`() throws {
    let store = try AppStyleFixture.makeStore()
    for style in WritingStyle.allCases {
      let resolved = store.resolvedStyle(hostBundleId: AppStyleFixture.messagesBundleId, defaultStyle: style)
      #expect(resolved == style)
    }
  }
}

private enum AppStyleFixture {

  static let messagesBundleId = "com.apple.MobileSMS"
  static let mailBundleId = "com.apple.mobilemail"
  static let entryName = "Test App"

  static let appWritingStylesKey = "appWritingStyles"

  static func makeStore() throws -> AppStyleStore {
    let suiteName = self.uniqueSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return AppStyleStore(defaults: defaults)
  }

  static func uniqueSuiteName() -> String {
    "app.sayboard.tests.\(UUID().uuidString)"
  }

  static func entry(_ bundleId: String, _ style: WritingStyle) -> AppStyleEntry {
    AppStyleEntry(bundleId: bundleId, name: self.entryName, iconURL: nil, style: style)
  }
}
