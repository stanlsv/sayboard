
import Foundation

extension SharedSettings {

  var entitlementStatus: EntitlementStatus {
    get {
      self.defaults.string(forKey: SharedKey.entitlementStatus).flatMap(EntitlementStatus.init(rawValue:)) ?? .unknown
    }
    nonmutating set { self.defaults.set(newValue.rawValue, forKey: SharedKey.entitlementStatus) }
  }

  var entitlementEnvironment: String? {
    get { self.defaults.string(forKey: SharedKey.entitlementEnvironment) }
    nonmutating set { self.defaults.set(newValue, forKey: SharedKey.entitlementEnvironment) }
  }

  var freeWordsUsed: Int {
    self.defaults.integer(forKey: SharedKey.freeWordsUsed)
  }

  var dictationAllowance: DictationAllowance {
    DictationAllowance(status: self.entitlementStatus, wordsUsed: self.freeWordsUsed)
  }

  var isDictationLocked: Bool {
    StoreBuild.isEnabled && self.dictationAllowance.isExhausted
  }

  func chargeFreeWords(_ count: @autoclosure () -> Int, storeBuild: Bool = StoreBuild.isEnabled) {
    guard storeBuild, self.entitlementStatus != .unlocked else { return }
    let words = count()
    guard words > 0 else { return }
    self.defaults.set(self.freeWordsUsed + words, forKey: SharedKey.freeWordsUsed)
  }
}
