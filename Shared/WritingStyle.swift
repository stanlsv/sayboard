import Foundation

enum WritingStyle: String, Codable, Sendable, CaseIterable {
  case formal
  case casual
  case veryCasual

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    guard let style = Self(stored: rawValue) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unknown WritingStyle raw value: \(rawValue)",
      )
    }
    self = style
  }

  init?(stored rawValue: String) {
    switch rawValue {
    case "informal": self = .casual
    case "official": self = .formal
    default:
      guard let value = Self(rawValue: rawValue) else { return nil }
      self = value
    }
  }

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
    case .formal: "Wait, did you see that? He can’t believe it happened."
    case .casual: "Wait, did you see that? He can’t believe it happened"
    case .veryCasual: "wait did you see that? he can’t believe it happened"
    }
  }

}

enum TextStyleFormatter {

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

  private static let sentenceEndingPeriods: Set<Character> = [
    ".",
    "\u{3002}",
    "\u{0964}",
  ]

  private static let commas: Set<Character> = [
    ",",
    "\u{FF0C}",
    "\u{3001}",
    "\u{060C}",
  ]

  private static let semicolons: Set<Character> = [
    ";",
    "\u{FF1B}",
  ]

  private static let colons: Set<Character> = [
    ":",
    "\u{FF1A}",
  ]

  private static let veryCasualStripSet: Set<Character> = {
    var set = sentenceEndingPeriods
    set.formUnion(commas)
    set.formUnion(semicolons)
    set.formUnion(colons)
    return set
  }()

  private static var literalSpan: Regex<Substring> {
    #/https?://\S+|www\.\S+|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|\d{1,2}[:：]\d{2}(?:[:：]\d{2})?|\d+[.,]\d+/#
  }

  private static func applyCasual(_ text: String) -> String {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    let processed = lines.map { line in
      var result = String(line)
      let trimmed = result.trimmingCharacters(in: .whitespaces)
      if let lastChar = trimmed.last, self.sentenceEndingPeriods.contains(lastChar) {
        if let lastPeriodIndex = result.lastIndex(where: { self.sentenceEndingPeriods.contains($0) }) {
          result.remove(at: lastPeriodIndex)
        }
        while result.last?.isWhitespace == true {
          result.removeLast()
        }
      }
      return result
    }
    return processed.joined(separator: "\n")
  }

  private static func applyVeryCasual(_ text: String) -> String {
    var result = ""
    var cursor = text.startIndex
    for match in text.matches(of: self.literalSpan) {
      result += self.strippingProse(text[cursor ..< match.range.lowerBound])
      result += text[match.range]
      cursor = match.range.upperBound
    }
    result += self.strippingProse(text[cursor...])
    return self.tidyingWhitespace(result)
  }

  private static func strippingProse(_ text: Substring) -> String {
    String(text.lowercased().filter { !self.veryCasualStripSet.contains($0) })
  }

  private static func tidyingWhitespace(_ text: String) -> String {
    var result = text
    while result.contains("  ") {
      result = result.replacingOccurrences(of: "  ", with: " ")
    }
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

struct AppStyleEntry: Codable, Sendable, Identifiable, Hashable {
  let bundleId: String
  let name: String
  let iconURL: URL?
  var style: WritingStyle

  var id: String {
    self.bundleId
  }
}

struct AppStyleStore {

  init() {
    self.init(defaults: AppGroup.sharedDefaults ?? .standard)
  }

  init(defaults: UserDefaults) {
    self.defaults = defaults
  }

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

  func resolvedStyle(hostBundleId: String?, defaultStyle: WritingStyle) -> WritingStyle {
    hostBundleId.flatMap { self.style(for: $0) } ?? defaultStyle
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

  private let defaults: UserDefaults
}
