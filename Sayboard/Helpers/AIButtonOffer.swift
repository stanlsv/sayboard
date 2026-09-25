
enum AIButtonOffer {
  static let closedKey = "aiButtonOfferClosed"

  static func isDue(isClosed: Bool, canRunModel: Bool, hasTextModel: Bool, isDictationLocked: Bool) -> Bool {
    !isClosed && canRunModel && !hasTextModel && !isDictationLocked
  }
}
