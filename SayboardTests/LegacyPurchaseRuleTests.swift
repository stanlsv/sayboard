import Foundation
import Testing
@testable import Sayboard

@Suite("Recognizing buyers of the paid app")
struct LegacyPurchaseRuleTests {

  @Test
  func `the app ships with the cutoff of the switch to Free`() {
    #expect(LegacyPurchaseRule.freeSwitchCutoff == Self.shippedCutoff)
  }

  @Test
  func `the app ships with a build number above every paid build`() throws {
    let build = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    let buildNumber = try #require(Int(build))
    #expect(buildNumber > LegacyPurchaseRule.lastPaidBuild)
  }

  @Test
  func `a download before the switch is a buyer, whatever build it started on`() {
    #expect(Self.isLegacy(downloaded: Self.beforeSwitch, build: Self.firstFreeBuild))
  }

  @Test
  func `a late download of a paid build is still a buyer`() {
    #expect(Self.isLegacy(downloaded: Self.afterSwitch, build: "15"))
  }

  @Test
  func `a one-digit paid build is compared as a number, not as text`() {
    #expect(Self.isLegacy(downloaded: Self.afterSwitch, build: "5"))
    #expect(Self.isLegacy(downloaded: Self.afterSwitch, build: "2"))
  }

  @Test
  func `a download after the switch of a free build is not a buyer`() {
    #expect(!Self.isLegacy(downloaded: Self.afterSwitch, build: Self.firstFreeBuild))
  }

  @Test
  func `a download at the cutoff itself is not a buyer`() {
    #expect(!Self.isLegacy(downloaded: Self.switchDate, build: Self.firstFreeBuild))
  }

  @Test
  func `without a cutoff the build number alone decides`() {
    #expect(Self.isLegacy(downloaded: Self.afterSwitch, build: "15", cutoff: nil))
    #expect(!Self.isLegacy(downloaded: Self.beforeSwitch, build: Self.firstFreeBuild, cutoff: nil))
  }

  @Test
  func `a build number that is not an integer does not make a buyer`() {
    #expect(!Self.isLegacy(downloaded: Self.afterSwitch, build: "1.0"))
  }

  @Test
  func `the sandbox never counts as a buyer`() {
    #expect(!Self.isLegacy(environment: .sandbox, downloaded: Self.sandboxDownloadDate, build: "1.0"))
  }

  @Test
  func `a StoreKit test run in Xcode never counts as a buyer`() {
    #expect(!Self.isLegacy(environment: .xcode, downloaded: .distantPast, build: "1"))
  }

  private static let shippedCutoff = Date(timeIntervalSince1970: 1_789_948_800)
  private static let switchDate = Date(timeIntervalSince1970: 1_790_000_000)
  private static let beforeSwitch = switchDate.addingTimeInterval(-86_400)
  private static let afterSwitch = switchDate.addingTimeInterval(86_400)
  private static let sandboxDownloadDate = Date(timeIntervalSince1970: 1_375_340_400)
  private static let firstFreeBuild = "16"

  private static func isLegacy(
    environment: PurchaseEnvironment = .production,
    downloaded: Date,
    build: String,
    cutoff: Date? = Self.switchDate,
  ) -> Bool {
    LegacyPurchaseRule.isLegacyBuyer(
      environment: environment,
      originalPurchaseDate: downloaded,
      originalAppVersion: build,
      cutoff: cutoff,
    )
  }
}
