import Foundation

extension Locale {
  func capitalizedLanguageName(forLanguageCode code: String) -> String {
    guard let name = self.localizedString(forLanguageCode: code) else { return code }
    return name.prefix(1).uppercased() + name.dropFirst()
  }
}
