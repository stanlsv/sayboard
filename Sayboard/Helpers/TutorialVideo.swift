import Foundation

// TutorialVideo -- Maps setup banners to bundled PiP tutorial video assets.
// Per-language videos are named `tutorial-{name}-{lang}.mp4`.

enum TutorialVideo: String {
  case microphone = "tutorial-microphone"
  case addKeyboard = "tutorial-add-keyboard"
  case fullAccess = "tutorial-full-access"

  func url(for language: String) -> URL? {
    let lang = AppLanguageConfig.supported.contains(language) ? language : AppLanguageConfig.fallback
    return Bundle.main.url(forResource: "\(self.rawValue)-\(lang)", withExtension: "mp4")
  }
}
