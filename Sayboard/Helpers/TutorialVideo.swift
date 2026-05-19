import Foundation

// TutorialVideo -- Maps setup banners to bundled PiP tutorial video assets.
// Per-language videos are named `tutorial-{name}-{lang}.mp4`.

enum TutorialVideo: String {
  case microphone = "tutorial-microphone"
  case addKeyboard = "tutorial-add-keyboard"
  case fullAccess = "tutorial-full-access"

  func url(for language: String) -> URL? {
    let lang = AppLanguageConfig.supported.contains(language) ? language : AppLanguageConfig.fallback
    if let url = Bundle.main.url(forResource: "\(self.rawValue)-\(lang)", withExtension: "mp4") {
      return url
    }
    // Locale-specific video missing (e.g., newly-added languages without recorded tutorials).
    // Fall back to English so users still see the iOS-Settings walkthrough.
    return Bundle.main.url(forResource: "\(self.rawValue)-\(AppLanguageConfig.fallback)", withExtension: "mp4")
  }
}
