import Testing

@Suite("Free dictation allowance")
struct DictationAllowanceTests {

  @Test
  func `a new install has the whole allowance left`() {
    let allowance = DictationAllowance(status: .unknown, wordsUsed: 0)
    #expect(allowance.remainingWords == Self.freeWords)
    #expect(!allowance.isExhausted)
  }

  @Test
  func `used words come off the allowance`() {
    let allowance = DictationAllowance(status: .free, wordsUsed: Self.partlyUsed)
    #expect(allowance.remainingWords == Self.freeWords - Self.partlyUsed)
    #expect(!allowance.isExhausted)
  }

  @Test
  func `a verified free user has used up the allowance once every word is spent`() {
    let allowance = DictationAllowance(status: .free, wordsUsed: Self.freeWords)
    #expect(allowance.remainingWords == 0)
    #expect(allowance.isExhausted)
  }

  @Test
  func `overspending never shows a negative remainder`() {
    let allowance = DictationAllowance(status: .free, wordsUsed: Self.freeWords + Self.overspend)
    #expect(allowance.remainingWords == 0)
    #expect(allowance.isExhausted)
  }

  @Test
  func `an unverified status never locks, however many words were used`() {
    let allowance = DictationAllowance(status: .unknown, wordsUsed: Self.freeWords + Self.overspend)
    #expect(!allowance.isExhausted)
  }

  @Test
  func `an unlocked user is never locked`() {
    let allowance = DictationAllowance(status: .unlocked, wordsUsed: Self.freeWords + Self.overspend)
    #expect(!allowance.isExhausted)
  }

  private static let freeWords = 3_000
  private static let partlyUsed = 860
  private static let overspend = 412
}
