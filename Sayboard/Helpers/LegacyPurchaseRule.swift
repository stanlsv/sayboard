
import Foundation

enum PurchaseEnvironment: Sendable {
  case production
  case sandbox
  case xcode
}

enum LegacyPurchaseRule {

  static let lastPaidBuild = 15

  static let freeSwitchCutoff = Date(timeIntervalSince1970: 1_789_948_800)

  static func isLegacyBuyer(
    environment: PurchaseEnvironment,
    originalPurchaseDate: Date,
    originalAppVersion: String,
    cutoff: Date? = freeSwitchCutoff,
  ) -> Bool {
    guard environment == .production else { return false }
    if let cutoff, originalPurchaseDate < cutoff {
      return true
    }
    guard let build = Int(originalAppVersion) else { return false }
    return build <= self.lastPaidBuild
  }
}
