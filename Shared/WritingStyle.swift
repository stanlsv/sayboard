import Foundation

// MARK: - WritingStyle

enum WritingStyle: String, Codable, Sendable, CaseIterable {
  case formal
  case casual
  case veryCasual

  // MARK: Lifecycle

  /// Custom decoder to migrate old raw values
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    switch rawValue {
    case "informal": self = .casual
    case "official": self = .veryCasual
    default:
      guard let value = Self(rawValue: rawValue) else {
        throw DecodingError.dataCorruptedError(
          in: container,
          debugDescription: "Unknown WritingStyle raw value: \(rawValue)",
        )
      }
      self = value
    }
  }

  // MARK: Internal

  var displayNameKey: String {
    switch self {
    case .formal: "Formal"
    case .casual: "Casual"
    case .veryCasual: "Very Casual"
    }
  }

  var descriptionKey: String {
    switch self {
    case .formal: "Caps · full punctuation"
    case .casual: "Caps · less punctuation"
    case .veryCasual: "No caps · no punctuation"
    }
  }

  var exampleKey: String {
    switch self {
    case .formal: "Wait, did you see that? He can't believe it happened."
    case .casual: "Wait, did you see that? He can't believe it happened"
    case .veryCasual: "wait did you see that? he can't believe it happened"
    }
  }

}

// MARK: - TextStyleFormatter

enum TextStyleFormatter {

  // MARK: Internal

  static func format(_ text: String, style: WritingStyle) -> String {
    switch style {
    case .formal:
      text
    case .casual:
      self.applyCasual(text)
    case .veryCasual:
      self.applyVeryCasual(text)
    }
  }

  // MARK: Private

  /// Sentence-ending periods and their CJK/Indic equivalents.
  private static let sentenceEndingPeriods: Set<Character> = [
    ".", // ASCII period
    "\u{3002}", // CJK fullwidth period
    "\u{0964}", // Devanagari danda
  ]

  /// Commas and their CJK/Arabic equivalents.
  private static let commas: Set<Character> = [
    ",", // ASCII comma
    "\u{FF0C}", // Fullwidth comma
    "\u{3001}", // Ideographic comma
    "\u{060C}", // Arabic comma
  ]

  /// Semicolons and their fullwidth equivalents.
  private static let semicolons: Set<Character> = [
    ";", // ASCII semicolon
    "\u{FF1B}", // Fullwidth semicolon
  ]

  /// Colons and their fullwidth equivalents.
  private static let colons: Set<Character> = [
    ":", // ASCII colon
    "\u{FF1A}", // Fullwidth colon
  ]

  /// Characters to strip in Very Casual mode (periods + commas + semicolons + colons).
  private static let veryCasualStripSet: Set<Character> = {
    var set = sentenceEndingPeriods
    set.formUnion(commas)
    set.formUnion(semicolons)
    set.formUnion(colons)
    return set
  }()

  private static func applyCasual(_ text: String) -> String {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    let processed = lines.map { line in
      var result = String(line)
      // Remove trailing whitespace first to find trailing period
      let trimmed = result.trimmingCharacters(in: .whitespaces)
      if let lastChar = trimmed.last, self.sentenceEndingPeriods.contains(lastChar) {
        // Remove the last period and any trailing whitespace
        if let lastPeriodIndex = result.lastIndex(where: { self.sentenceEndingPeriods.contains($0) }) {
          result.remove(at: lastPeriodIndex)
        }
        // Trim trailing whitespace that may remain
        while result.last?.isWhitespace == true {
          result.removeLast()
        }
      }
      return result
    }
    return processed.joined(separator: "\n")
  }

  private static func applyVeryCasual(_ text: String) -> String {
    var result = text.lowercased()
    result = String(result.filter { !self.veryCasualStripSet.contains($0) })
    // Collapse multiple consecutive spaces into a single space
    while result.contains("  ") {
      result = result.replacingOccurrences(of: "  ", with: " ")
    }
    // Trim leading/trailing whitespace per line
    let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
    let trimmed = lines.map { line in
      var trimmedLine = String(line)
      while trimmedLine.first?.isWhitespace == true { trimmedLine.removeFirst() }
      while trimmedLine.last?.isWhitespace == true { trimmedLine.removeLast() }
      return trimmedLine
    }
    return trimmed.joined(separator: "\n")
  }
}

// MARK: - AppStyleEntry

struct AppStyleEntry: Codable, Sendable, Identifiable, Hashable {
  let bundleId: String
  let name: String
  let iconURL: URL?
  var style: WritingStyle

  var id: String {
    self.bundleId
  }
}

// MARK: - AppStyleStore

// AppStyleStore -- JSON encode/decode [AppStyleEntry] via App Group UserDefaults

struct AppStyleStore {

  // MARK: Internal

  func loadEntries() -> [AppStyleEntry] {
    guard let data = self.defaults.data(forKey: SharedKey.appWritingStyles) else {
      return []
    }
    return (try? JSONDecoder().decode([AppStyleEntry].self, from: data)) ?? []
  }

  func saveEntries(_ entries: [AppStyleEntry]) {
    guard let data = try? JSONEncoder().encode(entries) else {
      return
    }
    self.defaults.set(data, forKey: SharedKey.appWritingStyles)
  }

  func style(for bundleId: String) -> WritingStyle? {
    self.loadEntries().first { $0.bundleId == bundleId }?.style
  }

  func addEntry(_ entry: AppStyleEntry) {
    var entries = self.loadEntries()
    if let index = entries.firstIndex(where: { $0.bundleId == entry.bundleId }) {
      entries[index] = entry
    } else {
      entries.append(entry)
    }
    self.saveEntries(entries)
  }

  func removeEntry(bundleId: String) {
    let entries = self.loadEntries().filter { $0.bundleId != bundleId }
    self.saveEntries(entries)
  }

  func updateStyle(for bundleId: String, style: WritingStyle) {
    var entries = self.loadEntries()
    guard let index = entries.firstIndex(where: { $0.bundleId == bundleId }) else {
      return
    }
    entries[index].style = style
    self.saveEntries(entries)
  }

  // MARK: Private

  private let defaults = AppGroup.sharedDefaults ?? .standard
}
