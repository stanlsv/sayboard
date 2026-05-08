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
  func `non-whisper engine variants do not support selection`() {
    #expect(!ModelVariant.parakeetV2.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineTiny.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineBase.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineTinyStreaming.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineSmallStreaming.supportsLanguageSelection)
    #expect(!ModelVariant.moonshineMediumStreaming.supportsLanguageSelection)
  }

  @Test
  func `parakeet v3 is gated until FluidAudio exposes the language hint`() {
    // Parakeet v3 supports 25 languages internally, but FluidAudio's public API
    // does not expose a language parameter, so the picker stays hidden.
    #expect(!ModelVariant.parakeetV3.supportsLanguageSelection)
  }

  @Test
  func `flag is true exactly for whisper multilingual variants`() {
    let supporting = ModelVariant.allCases.filter(\.supportsLanguageSelection)
    let expected: Set<ModelVariant> = [.whisperTiny, .whisperBase, .whisperSmall]
    #expect(Set(supporting) == expected)
  }
}
