

enum StoreFact: Sendable {
  case confirmed
  case ruledOut
  case unavailable
}

enum EntitlementResolver {
  static func resolve(
    purchase: StoreFact,
    legacyBuyer: StoreFact,
    previous: EntitlementStatus,
  ) -> EntitlementStatus {
    if purchase == .confirmed || legacyBuyer == .confirmed {
      return .unlocked
    }
    if purchase == .ruledOut, legacyBuyer == .ruledOut {
      return .free
    }
    return previous
  }

  static func previousStatus(
    stored: EntitlementStatus,
    storedEnvironment: String?,
    currentEnvironment: String?,
  ) -> EntitlementStatus {
    guard let currentEnvironment, storedEnvironment != currentEnvironment else { return stored }
    return .unknown
  }
}
