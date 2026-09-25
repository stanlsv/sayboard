
import NaturalLanguage

enum WordCounter {
  static func count(_ text: String) -> Int {
    let tokenizer = NLTokenizer(unit: .word)
    tokenizer.string = text
    var words = 0
    tokenizer.enumerateTokens(in: text.startIndex ..< text.endIndex) { _, _ in
      words += 1
      return true
    }
    return words
  }
}
