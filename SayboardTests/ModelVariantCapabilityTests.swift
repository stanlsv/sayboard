import Testing

@Suite("ModelVariant.supportsLanguageSelection")
struct ModelVariantCapabilityTests {

  @Test
  func `whisper variants support selection`() {
    #expect(ModelVariant.whisperTiny.supportsLanguageSelection)
    #expect(ModelVariant.whisperBase.supportsLanguageSelection)
    #expect(ModelVariant.whisperSmall.supportsLanguageSelection)
  }

  @Test
  func `parakeet v3 supports selection`() {
    #expect(ModelVariant.parakeetV3.supportsLanguageSelection)
  }

  @Test
  func `english-only variants do not support selection`() {
    #expect(!ModelVariant.parakeetV2.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineTiny.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineBase.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineTinyStreaming.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineSmallStreaming.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineMediumStreaming.supportsLanguageSelection)
  }

  @Test
  func `flag is true exactly for the multilingual whisper and parakeet variants`() {
    let supporting = ModelVariant.allCases.filter(\.supportsLanguageSelection)
    let expected: Set<ModelVariant> = [.whisperTiny, .whisperBase, .whisperSmall, .parakeetV3]
    #expect(Set(supporting) == expected)
  }
}
