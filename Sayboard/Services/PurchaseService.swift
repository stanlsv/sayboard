
#if APPSTORE

import StoreKit

@MainActor
final class PurchaseService: ObservableObject {

  private init() { }

  enum PurchaseOutcome {
    case purchased
    case pending
    case cancelled
    case failed
  }

  enum RestoreOutcome {
    case restored
    case nothingToRestore
    case cancelled
    case failed
  }

  static let shared = PurchaseService()

  @Published private(set) var product: Product?

  func start() {
    guard self.updatesTask == nil else { return }
    self.updatesTask = Task { [weak self] in
      for await update in Transaction.updates {
        await self?.handleUpdate(update)
      }
    }
    self.launchCheck = Task { await self.refreshStatus(refreshingAppTransaction: false) }
  }

  func loadProductIfNeeded() async {
    guard self.product == nil else { return }
    do {
      self.product = try await Product.products(for: [StoreProduct.fullVersionID]).first
    } catch { }
  }

  func complete(_ result: Product.PurchaseResult) async -> PurchaseOutcome {
    switch result {
    case .success(let verification):
      guard case .verified(let transaction) = verification else {
        return .failed
      }
      self.apply(.unlocked, environment: transaction.environment.rawValue)
      await transaction.finish()
      return .purchased

    case .pending:
      return .pending

    case .userCancelled:
      return .cancelled

    @unknown default:
      return .failed
    }
  }

  func restore() async -> RestoreOutcome {
    do {
      try await AppStore.sync()
    } catch StoreKitError.userCancelled {
      return .cancelled
    } catch {
      return .failed
    }
    await self.refreshStatus(refreshingAppTransaction: true)
    switch SharedSettings().entitlementStatus {
    case .unlocked: return .restored
    case .free: return .nothingToRestore
    case .unknown: return .failed
    }
  }

  func refreshIfUnverified() {
    guard !self.didRetryUnverified else { return }
    self.didRetryUnverified = true
    Task {
      await self.launchCheck?.value
      guard SharedSettings().entitlementStatus == .unknown else { return }
      await self.refreshStatus(refreshingAppTransaction: false)
    }
  }

  private struct StoreAnswer {
    let fact: StoreFact
    let environment: String?
  }

  private var updatesTask: Task<Void, Never>?
  private var launchCheck: Task<Void, Never>?
  private var didRetryUnverified = false

  private static func legacyBuyerAnswer(refreshing: Bool) async -> StoreAnswer {
    var appTransaction = await self.verifiedAppTransaction(refresh: false)
    if appTransaction == nil, refreshing {
      appTransaction = await self.verifiedAppTransaction(refresh: true)
    }
    guard let appTransaction else { return StoreAnswer(fact: .unavailable, environment: nil) }
    let isBuyer = LegacyPurchaseRule.isLegacyBuyer(
      environment: self.purchaseEnvironment(appTransaction.environment),
      originalPurchaseDate: appTransaction.originalPurchaseDate,
      originalAppVersion: appTransaction.originalAppVersion,
    )
    return StoreAnswer(fact: isBuyer ? .confirmed : .ruledOut, environment: appTransaction.environment.rawValue)
  }

  private static func verifiedAppTransaction(refresh: Bool) async -> AppTransaction? {
    do {
      let result =
        if refresh {
          try await AppTransaction.refresh()
        } else {
          try await AppTransaction.shared
        }
      guard case .verified(let appTransaction) = result else {
        return nil
      }
      return appTransaction
    } catch {
      return nil
    }
  }

  private static func purchaseAnswer(legacyBuyer: StoreFact, previous: EntitlementStatus) async -> StoreAnswer {
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result, transaction.productID == StoreProduct.fullVersionID {
        return StoreAnswer(fact: .confirmed, environment: transaction.environment.rawValue)
      }
    }
    switch legacyBuyer {
    case .unavailable:
      return StoreAnswer(fact: .unavailable, environment: nil)
    case .confirmed:
      return StoreAnswer(fact: .ruledOut, environment: nil)
    case .ruledOut:
      guard previous == .unlocked else { return StoreAnswer(fact: .ruledOut, environment: nil) }
      return await self.latestPurchaseAnswer()
    }
  }

  private static func latestPurchaseAnswer() async -> StoreAnswer {
    guard case .verified(let transaction)? = await Transaction.latest(for: StoreProduct.fullVersionID) else {
      return StoreAnswer(fact: .unavailable, environment: nil)
    }
    return self.answer(for: transaction)
  }

  private static func answer(for transaction: Transaction) -> StoreAnswer {
    StoreAnswer(
      fact: transaction.revocationDate == nil ? .confirmed : .ruledOut,
      environment: transaction.environment.rawValue,
    )
  }

  private static func purchaseEnvironment(_ environment: AppStore.Environment) -> PurchaseEnvironment {
    switch environment {
    case .production: .production
    case .xcode: .xcode
    default: .sandbox
    }
  }

  private func refreshStatus(refreshingAppTransaction: Bool, knownPurchase: StoreAnswer? = nil) async {
    let legacyBuyer = await Self.legacyBuyerAnswer(refreshing: refreshingAppTransaction)
    let settings = SharedSettings()
    let stored = settings.entitlementStatus
    let storedEnvironment = settings.entitlementEnvironment
    let previous = EntitlementResolver.previousStatus(
      stored: stored,
      storedEnvironment: storedEnvironment,
      currentEnvironment: legacyBuyer.environment,
    )
    let purchase =
      if let knownPurchase {
        knownPurchase
      } else {
        await Self.purchaseAnswer(legacyBuyer: legacyBuyer.fact, previous: previous)
      }
    let current = SharedSettings()
    guard current.entitlementStatus == stored, current.entitlementEnvironment == storedEnvironment else { return }
    let status = EntitlementResolver.resolve(purchase: purchase.fact, legacyBuyer: legacyBuyer.fact, previous: previous)
    self.apply(status, environment: legacyBuyer.environment ?? purchase.environment)
  }

  private func handleUpdate(_ update: VerificationResult<Transaction>) async {
    guard case .verified(let transaction) = update else {
      return
    }
    let isPurchase = transaction.productID == StoreProduct.fullVersionID && transaction.revocationDate == nil
    let knownPurchase = isPurchase ? Self.answer(for: transaction) : nil
    await self.refreshStatus(refreshingAppTransaction: false, knownPurchase: knownPurchase)
    await transaction.finish()
  }

  private func apply(_ status: EntitlementStatus, environment: String?) {
    let settings = SharedSettings()
    if let environment, settings.entitlementEnvironment != environment {
      settings.entitlementEnvironment = environment
    }
    guard settings.entitlementStatus != status else { return }
    settings.entitlementStatus = status
    settings.synchronize()
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.dictationLockChanged)
  }
}
#endif
