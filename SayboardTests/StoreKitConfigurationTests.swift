import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Sayboard

@Suite("Local StoreKit configuration", .serialized)
struct StoreKitConfigurationTests {

  @Test
  func `the configuration sells the product the app asks for, as a non-consumable`() throws {
    let url = try #require(Bundle(for: BundleToken.self).url(forResource: "Sayboard", withExtension: "storekit"))
    let configuration = try JSONDecoder().decode(StoreKitFile.self, from: Data(contentsOf: url))
    let product = try #require(configuration.products.first)
    #expect(configuration.products.count == 1)
    #expect(product.productID == Self.productID)
    #expect(product.productID == StoreProduct.fullVersionID)
    #expect(product.type == Self.nonConsumableType)
  }

  @Test(.disabled(
    if: Self.isStoreKitTestingBroken,
    "Skipped on iOS 26 simulators: SKTestSession serves no products on 26.3 to 26.5",
  ))
  func `the StoreKit test session serves the configured product at its configured price`() async throws {
    let url = try #require(Bundle(for: BundleToken.self).url(forResource: "Sayboard", withExtension: "storekit"))
    let configuration = try JSONDecoder().decode(StoreKitFile.self, from: Data(contentsOf: url))
    let configuredPrice = try #require(configuration.products.first.flatMap { Decimal(string: $0.displayPrice) })
    let session = try SKTestSession(contentsOf: url)
    session.resetToDefaultState()
    session.disableDialogs = true
    session.clearTransactions()
    defer { session.clearTransactions() }

    let products = try await Product.products(for: [Self.productID])
    let product = try #require(products.first)
    #expect(products.count == 1)
    #expect(product.type == .nonConsumable)
    #expect(product.price == configuredPrice)
  }

  private static let productID = "app.sayboard.fullversion"
  private static let nonConsumableType = "NonConsumable"

  private static var isStoreKitTestingBroken: Bool {
    #if targetEnvironment(simulator)
    ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
    #else
    false
    #endif
  }
}

private struct StoreKitFile: Decodable {
  struct Product: Decodable {
    let productID: String
    let type: String
    let displayPrice: String
  }

  let products: [Product]
}

private final class BundleToken { }
