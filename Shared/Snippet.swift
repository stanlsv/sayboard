// Snippet -- Data model and expansion engine for text replacement snippets

import Foundation

// MARK: - Snippet

struct Snippet: Codable, Identifiable, Sendable, Equatable {

  // MARK: Lifecycle

  init(id: UUID = UUID(), trigger: String, replacement: String, isEnabled: Bool = true) {
    self.id = id
    self.trigger = trigger
    self.replacement = replacement
    self.isEnabled = isEnabled
  }

  // MARK: Internal

  let id: UUID
  var trigger: String
  var replacement: String
  var isEnabled: Bool
}

// MARK: - SnippetExpander

enum SnippetExpander {

  /// Expands all enabled snippet triggers in the given text.
  /// Matches are case-insensitive and respect word boundaries.
  /// Longer triggers are matched first to prevent partial overlap.
  static func expand(_ text: String, snippets: [Snippet]) -> String {
    let activeSnippets = snippets
      .filter { $0.isEnabled && !$0.trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .sorted { $0.trigger.count > $1.trigger.count }

    guard !activeSnippets.isEmpty else { return text }

    var result = text
    for snippet in activeSnippets {
      let trigger = snippet.trigger
      let escapedTrigger = NSRegularExpression.escapedPattern(for: trigger)
      let leading = trigger.first.map { $0.isLetter || $0.isNumber || $0 == "_" } ?? false
      let trailing = trigger.last.map { $0.isLetter || $0.isNumber || $0 == "_" } ?? false
      let pattern = "\(leading ? "\\b" : "")\(escapedTrigger)\(trailing ? "\\b" : "")"
      guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
        continue
      }
      let escapedReplacement = NSRegularExpression.escapedTemplate(for: snippet.replacement)
      result = regex.stringByReplacingMatches(
        in: result,
        range: NSRange(result.startIndex..., in: result),
        withTemplate: escapedReplacement,
      )
    }
    return result
  }
}
