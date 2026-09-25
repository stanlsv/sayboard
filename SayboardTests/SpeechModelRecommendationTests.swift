import Testing

@Suite("Recommending a speech model for the languages someone dictates in")
struct SpeechModelRecommendationTests {

  @Test
  func `region and script are dropped from device identifiers`() {
    #expect(SpeechModelRecommendation.speechCode(forIdentifier: "ru-RU") == "ru")
    #expect(SpeechModelRecommendation.speechCode(forIdentifier: "zh-Hans-CN") == "zh")
    #expect(SpeechModelRecommendation.speechCode(forIdentifier: "pt-BR") == "pt")
  }

  @Test
  func `norwegian bokmål maps to the code whisper uses`() {
    #expect(SpeechModelRecommendation.speechCode(forIdentifier: "nb-NO") == "no")
    #expect(SpeechModelRecommendation.speechCode(forIdentifier: "nn-NO") == "nn")
  }

  @Test
  func `keyboards that are not languages are ignored`() {
    #expect(SpeechModelRecommendation.speechCode(forIdentifier: "mis") == nil)
    #expect(SpeechModelRecommendation.speechCode(forIdentifier: "emoji") == nil)
  }

  @Test
  func `device languages keep their order without duplicates`() {
    let codes = SpeechModelRecommendation.speechCodes(from: ["ru-RU", "en-US", "ru", "emoji", "en-GB"])
    #expect(codes == ["ru", "en"])
  }

  @Test
  func `european languages get parakeet v3`() {
    #expect(Self.recommend(["ru", "en"]) == .parakeetV3)
  }

  @Test
  func `a language parakeet does not know gets whisper small`() {
    #expect(Self.recommend(["ru", "ja"]) == .whisperSmall)
  }

  @Test
  func `no languages means any language and the widest model`() {
    #expect(Self.recommend([]) == .whisperSmall)
  }

  @Test
  func `a device that cannot run parakeet gets whisper small`() {
    let variant = Self.recommend(["ru", "en"]) { $0 != .parakeetV3 }
    #expect(variant == .whisperSmall)
  }

  @Test
  func `a device that cannot run whisper small gets whisper base`() {
    let variant = Self.recommend(["ja"]) { $0 != .parakeetV3 && $0 != .whisperSmall }
    #expect(variant == .whisperBase)
  }

  @Test
  func `whisper turbo is never the recommendation`() {
    for languages in Self.languageSets {
      #expect(Self.recommend(languages) != .whisperTurbo)
    }
  }

  @Test
  func `alternatives cover every chosen language`() {
    let alternatives = SpeechModelRecommendation.alternatives(
      languages: ["ru", "en"],
      excluding: .parakeetV3,
    ) { _ in true }
    #expect(alternatives == [.whisperSmall, .whisperTurbo, .whisperBase])
  }

  @Test
  func `alternatives for any language are the other whisper models`() {
    let alternatives = SpeechModelRecommendation.alternatives(
      languages: [],
      excluding: .whisperSmall,
    ) { _ in true }
    #expect(alternatives == [.whisperTurbo, .whisperBase, .whisperTiny])
  }

  @Test
  func `alternatives for english start with parakeet v2`() {
    let alternatives = SpeechModelRecommendation.alternatives(
      languages: ["en"],
      excluding: .parakeetV3,
    ) { _ in true }
    #expect(alternatives.first == .parakeetV2)
  }

  @Test
  func `alternatives leave out models the device cannot run`() {
    let alternatives = SpeechModelRecommendation.alternatives(
      languages: ["ru", "en"],
      excluding: .parakeetV3,
    ) { $0 != .whisperTurbo }
    #expect(!alternatives.contains(.whisperTurbo))
  }

  private static let languageSets: [[String]] = [["ru", "en"], ["ja"], ["hi", "en"], []]

  private static func recommend(
    _ languages: [String],
    isSupported: (ModelVariant) -> Bool = { _ in true },
  ) -> ModelVariant {
    SpeechModelRecommendation.recommendedVariant(languages: languages, isSupported: isSupported)
  }
}

@Suite("Languages carried from the onboarding into recognition")
struct PreferredLanguagesTests {

  @Test
  func `a multilingual model remembers the languages it recognizes`() {
    let languages = SpeechModelRecommendation.preferredLanguages(for: .parakeetV3, from: ["de", "en"])
    #expect(languages == ["de", "en"])
  }

  @Test
  func `a language the model does not recognize is dropped`() {
    let languages = SpeechModelRecommendation.preferredLanguages(for: .parakeetV3, from: ["de", "ja"])
    #expect(languages == ["de"])
  }

  @Test
  func `a model without a language choice remembers nothing`() {
    let single = ModelVariant.allCases.first { !$0.supportsLanguageSelection }
    if let single {
      #expect(SpeechModelRecommendation.preferredLanguages(for: single, from: ["de", "en"]).isEmpty)
    }
  }

  @Test
  func `saying nothing leaves every language open`() {
    #expect(SpeechModelRecommendation.preferredLanguages(for: .parakeetV3, from: []).isEmpty)
  }
}
