// TextSanitizer -- Strips STT artifacts that leak through WhisperKit's skipSpecialTokens

import Foundation

// MARK: - TextSanitizer

enum TextSanitizer {

  // MARK: Internal

  /// Strips transcription artifacts and normalizes whitespace.
  ///
  /// Removes in order:
  /// 1. Whisper special tokens (`<|...|>`)
  /// 2. HuggingFace unknown token (`<unk>`)
  /// 3. Bracket annotations (`[Music]`, `(Applause)`, `[BLANK_AUDIO]`, etc.)
  /// 4. Musical note symbols (U+2669..U+266F)
  /// 5. Unicode replacement character (U+FFFD)
  static func sanitize(_ text: String) -> String {
    var result = text

    // 1. Whisper special tokens: <|endoftext|>, <|startoftranscript|>, etc.
    result = self.whisperTokenPattern.stringByReplacingMatches(
      in: result,
      range: NSRange(result.startIndex..., in: result),
    )

    // 2. HuggingFace unknown token
    result = result.replacingOccurrences(of: "<unk>", with: "")

    // 3. Bracket annotations: [Music], (Applause), [BLANK_AUDIO], etc.
    result = self.bracketAnnotationPattern.stringByReplacingMatches(
      in: result,
      range: NSRange(result.startIndex..., in: result),
    )

    // 4. Musical note symbols
    result = String(result.filter { !self.musicalNoteSymbols.contains($0) })

    // 5. Unicode replacement character
    result = result.replacingOccurrences(of: "\u{FFFD}", with: "")

    // Normalize whitespace: collapse runs, trim edges
    result = self.collapseWhitespace(result)

    return result
  }

  // MARK: Private

  /// Matches Whisper special tokens like `<|endoftext|>`.
  private static let whisperTokenPattern: NSRegularExpression = // swiftlint:disable:next force_try
    try! NSRegularExpression(pattern: #"<\|[^|]+\|>"#)

  /// Matches bracket annotations like `[Music]` or `(Applause)`.
  private static let bracketAnnotationPattern: NSRegularExpression = // swiftlint:disable:next force_try
    try! NSRegularExpression(pattern: #"\[[\w\s]+\]|\([\w\s]+\)"#)

  /// Musical note Unicode symbols U+2669 through U+266F.
  private static let musicalNoteSymbols: Set<Character> = [
    "\u{2669}", // quarter note
    "\u{266A}", // eighth note
    "\u{266B}", // beamed eighth notes
    "\u{266C}", // beamed sixteenth notes
    "\u{266D}", // flat sign
    "\u{266E}", // natural sign
    "\u{266F}", // sharp sign
  ]

  private static func collapseWhitespace(_ text: String) -> String {
    var result = text
    while result.contains("  ") {
      result = result.replacingOccurrences(of: "  ", with: " ")
    }
    return result.trimmingCharacters(in: .whitespaces)
  }
}

// MARK: - NSRegularExpression + Convenience

extension NSRegularExpression {
  fileprivate func stringByReplacingMatches(in string: String, range: NSRange) -> String {
    self.stringByReplacingMatches(in: string, range: range, withTemplate: "")
  }
}
