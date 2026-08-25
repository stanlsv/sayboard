import Testing

@Suite("SpeechLanguages.parakeetV3")
struct SpeechLanguagesTests {

  @Test
  func `matches the model card's 25 European languages`() {
    #expect(SpeechLanguages.parakeetV3 == Self.parakeetV3ModelCard)
  }

  @Test
  func `excludes languages the model was never trained on`() {
    for code in Self.neverTrained {
      #expect(!SpeechLanguages.parakeetV3.contains(code))
    }
  }

  @Test
  func `every parakeet language is also covered by whisper`() {
    #expect(SpeechLanguages.parakeetV3.isSubset(of: SpeechLanguages.whisper))
  }

  private static let parakeetV3ModelCard: Set = [
    "bg",
    "cs",
    "da",
    "de",
    "el",
    "en",
    "es",
    "et",
    "fi",
    "fr",
    "hr",
    "hu",
    "it",
    "lt",
    "lv",
    "mt",
    "nl",
    "pl",
    "pt",
    "ro",
    "ru",
    "sk",
    "sl",
    "sv",
    "uk",
  ]

  private static let neverTrained = ["ar", "hi", "ja", "ko", "no", "tr", "zh"]

}
