import Foundation

enum TutorialVideo: String {
  case microphone = "tutorial-microphone"
  case addKeyboard = "tutorial-add-keyboard"
  case fullAccess = "tutorial-full-access"

  func url(for language: String) -> URL? {
    let lang = AppLanguageConfig.supported.contains(language) ? language : AppLanguageConfig.fallback
    if let url = Bundle.main.url(forResource: "\(self.rawValue)-\(lang)", withExtension: "mp4") {
      return url
    }
    return Bundle.main.url(forResource: "\(self.rawValue)-\(AppLanguageConfig.fallback)", withExtension: "mp4")
  }
}
