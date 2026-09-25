import Foundation
import Testing
@testable import Sayboard

@MainActor
@Suite("Styling a dictation made in an onboarding text field", .serialized)
struct OnboardingTextEntryTests {

  @Test
  func `an onboarding field gets the default style instead of the last app's`() throws {
    let store = try Self.storeStyling(Self.lastApp, as: .veryCasual)
    OnboardingTextEntry.isVisible = true
    defer { OnboardingTextEntry.isVisible = false }
    let host = OnboardingTextEntry.stylingHost(Self.lastApp)
    #expect(store.resolvedStyle(hostBundleId: host, defaultStyle: .formal) == .formal)
  }

  @Test
  func `other dictations keep the style of the app they were made in`() throws {
    let store = try Self.storeStyling(Self.lastApp, as: .veryCasual)
    OnboardingTextEntry.isVisible = false
    let host = OnboardingTextEntry.stylingHost(Self.lastApp)
    #expect(store.resolvedStyle(hostBundleId: host, defaultStyle: .formal) == .veryCasual)
  }

  private static let lastApp = "ph.telegra.Telegraph"

  private static func storeStyling(_ bundleId: String, as style: WritingStyle) throws -> AppStyleStore {
    let suiteName = "app.sayboard.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    let store = AppStyleStore(defaults: defaults)
    store.addEntry(AppStyleEntry(bundleId: bundleId, name: "Telegram", iconURL: nil, style: style))
    return store
  }
}
