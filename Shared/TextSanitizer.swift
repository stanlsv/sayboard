
import Foundation

enum TextSanitizer {

  static func sanitize(_ text: String) -> String {
    var result = text

    result = self.whisperTokenPattern.stringByReplacingMatches(
      in: result,
      range: NSRange(result.startIndex..., in: result),
    )

    result = result.replacingOccurrences(of: "<unk>", with: "")

    result = self.bracketAnnotationPattern.stringByReplacingMatches(
      in: result,
      range: NSRange(result.startIndex..., in: result),
    )

    result = String(result.filter { !self.musicalNoteSymbols.contains($0) })

    result = result.replacingOccurrences(of: "\u{FFFD}", with: "")

    result = self.collapseWhitespace(result)

    return result
  }

  private static let whisperTokenPattern: NSRegularExpression =
    try! NSRegularExpression(pattern: #"<\|[^|]+\|>"#)

  private static let bracketAnnotationPattern: NSRegularExpression =
    try! NSRegularExpression(pattern: #"\[[\w\s]+\]|\([\w\s]+\)"#)

  private static let musicalNoteSymbols: Set<Character> = [
    "\u{2669}",
    "\u{266A}",
    "\u{266B}",
    "\u{266C}",
    "\u{266D}",
    "\u{266E}",
    "\u{266F}",
  ]

  private static func collapseWhitespace(_ text: String) -> String {
    var result = text
    while result.contains("  ") {
      result = result.replacingOccurrences(of: "  ", with: " ")
    }
    return result.trimmingCharacters(in: .whitespaces)
  }
}

extension NSRegularExpression {
  fileprivate func stringByReplacingMatches(in string: String, range: NSRange) -> String {
    self.stringByReplacingMatches(in: string, range: range, withTemplate: "")
  }
}
