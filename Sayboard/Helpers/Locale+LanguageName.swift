import Foundation

extension Locale {
  /// Localized language name for `code`, capitalized. Returns `code` if unavailable.
  func capitalizedLanguageName(forLanguageCode code: String) -> String {
    guard let name = self.localizedString(forLanguageCode: code) else { return code }
    return name.prefix(1).uppercased() + name.dropFirst()
  }
}
