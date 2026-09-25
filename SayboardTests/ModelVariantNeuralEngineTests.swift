import Testing

@Suite("ModelVariant.specializesForNeuralEngine")
struct ModelVariantNeuralEngineTests {

  @Test
  func `whisper except turbo and parakeet specialize where the neural engine is available`() {
    let specializing = ModelVariant.allCases.filter { $0.specializesForNeuralEngine(neuralEngineBlocked: false) }
    let expected: Set<ModelVariant> = [.whisperTiny, .whisperBase, .whisperSmall, .parakeetV2, .parakeetV3]
    #expect(Set(specializing) == expected)
  }

  @Test
  func `no variant specializes where the neural engine is blocked`() {
    let specializing = ModelVariant.allCases.filter { $0.specializesForNeuralEngine(neuralEngineBlocked: true) }
    #expect(specializing.isEmpty)
  }
}
