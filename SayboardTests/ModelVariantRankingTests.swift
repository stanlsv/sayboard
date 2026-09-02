import Testing

@Suite("ModelVariant.catalogRank")
struct ModelVariantRankingTests {

  @Test
  func `the most accurate whisper outranks the fastest one`() {
    #expect(ModelVariant.whisperTurbo.catalogRank > ModelVariant.whisperTiny.catalogRank)
  }

  @Test
  func `ranked order is pinned`() {
    let ranked = ModelVariant.allCases.sorted { $0.catalogRank > $1.catalogRank }
    #expect(ranked == [
      .parakeetV2,
      .parakeetV3,
      .moonshineMediumStreaming,
      .whisperSmall,
      .whisperTurbo,
      .moonshineSmallStreaming,
      .moonshineBase,
      .whisperBase,
      .moonshineTinyStreaming,
      .moonshineTiny,
      .whisperTiny,
    ])
  }

  @Test
  func `no two variants share a rank`() {
    let ranks = ModelVariant.allCases.map(\.catalogRank)
    #expect(Set(ranks).count == ranks.count)
  }
}
