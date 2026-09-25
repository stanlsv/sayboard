
import Foundation

enum StoreBuild {
  static var isEnabled: Bool {
    #if APPSTORE
    true
    #else
    false
    #endif
  }
}

enum EntitlementStatus: String, Sendable {
  case unknown
  case free
  case unlocked
}

struct DictationAllowance: Equatable, Sendable {

  static let freeWords = 3_000

  let status: EntitlementStatus
  let wordsUsed: Int

  var remainingWords: Int {
    max(0, Self.freeWords - self.wordsUsed)
  }

  var isExhausted: Bool {
    self.status == .free && self.wordsUsed >= Self.freeWords
  }
}
