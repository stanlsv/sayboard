import Testing
@testable import Sayboard

@Suite("Turning StoreKit answers into the shared status")
struct EntitlementResolverTests {

  @Test
  func `a confirmed purchase unlocks`() {
    let status = EntitlementResolver.resolve(purchase: .confirmed, legacyBuyer: .ruledOut, previous: .free)
    #expect(status == .unlocked)
  }

  @Test
  func `a confirmed buyer of the paid app unlocks without a purchase`() {
    let status = EntitlementResolver.resolve(purchase: .ruledOut, legacyBuyer: .confirmed, previous: .unknown)
    #expect(status == .unlocked)
  }

  @Test
  func `both ruled out makes a free user`() {
    let status = EntitlementResolver.resolve(purchase: .ruledOut, legacyBuyer: .ruledOut, previous: .unknown)
    #expect(status == .free)
  }

  @Test
  func `a refund turns an unlocked user back into a free one`() {
    let status = EntitlementResolver.resolve(purchase: .ruledOut, legacyBuyer: .ruledOut, previous: .unlocked)
    #expect(status == .free)
  }

  @Test
  func `a failure to answer either question keeps what was verified before`() {
    #expect(EntitlementResolver.resolve(purchase: .unavailable, legacyBuyer: .unavailable, previous: .free) == .free)
    #expect(EntitlementResolver.resolve(purchase: .unavailable, legacyBuyer: .unavailable, previous: .unlocked) == .unlocked)
  }

  @Test
  func `an unlocked install without a refund on record stays unlocked`() {
    let status = EntitlementResolver.resolve(purchase: .unavailable, legacyBuyer: .ruledOut, previous: .unlocked)
    #expect(status == .unlocked)
  }

  @Test
  func `a confirmed answer wins over an unavailable one`() {
    #expect(EntitlementResolver.resolve(purchase: .confirmed, legacyBuyer: .unavailable, previous: .free) == .unlocked)
    #expect(EntitlementResolver.resolve(purchase: .unavailable, legacyBuyer: .confirmed, previous: .free) == .unlocked)
  }

  @Test
  func `a buyer confirmed both ways unlocks`() {
    let status = EntitlementResolver.resolve(purchase: .confirmed, legacyBuyer: .confirmed, previous: .unknown)
    #expect(status == .unlocked)
  }

  @Test
  func `an unavailable answer on a fresh install stays unknown`() {
    let status = EntitlementResolver.resolve(purchase: .unavailable, legacyBuyer: .unavailable, previous: .unknown)
    #expect(status == .unknown)
  }

  @Test
  func `a status verified in the same StoreKit environment still counts`() {
    let status = EntitlementResolver.previousStatus(
      stored: .unlocked,
      storedEnvironment: Self.sandbox,
      currentEnvironment: Self.sandbox,
    )
    #expect(status == .unlocked)
  }

  @Test
  func `a status verified in another StoreKit environment counts for nothing`() {
    let status = EntitlementResolver.previousStatus(
      stored: .unlocked,
      storedEnvironment: Self.sandbox,
      currentEnvironment: Self.production,
    )
    #expect(status == .unknown)
  }

  @Test
  func `a status stored without an environment counts for nothing once StoreKit names one`() {
    let status = EntitlementResolver.previousStatus(
      stored: .unlocked,
      storedEnvironment: nil,
      currentEnvironment: Self.production,
    )
    #expect(status == .unknown)
  }

  @Test
  func `without a current environment the stored status stands`() {
    let status = EntitlementResolver.previousStatus(
      stored: .free,
      storedEnvironment: Self.production,
      currentEnvironment: nil,
    )
    #expect(status == .free)
  }

  private static let sandbox = "Sandbox"
  private static let production = "Production"
}
