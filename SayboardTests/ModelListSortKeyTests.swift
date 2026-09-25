import Testing

@testable import Sayboard

@Suite("ModelListSortKey.precedes")
struct ModelListSortKeyTests {

  @Test
  func `the active model is listed first`() {
    let active = Self.key(isActive: true, isDownloaded: true, catalogRank: 0.1)
    let other = Self.key(isDownloaded: true, isRecommended: true, catalogRank: 0.9)
    #expect(active.precedes(other))
    #expect(!other.precedes(active))
  }

  @Test
  func `a downloaded model is listed above one that is not`() {
    let downloaded = Self.key(isDownloaded: true, catalogRank: 0.1)
    let other = Self.key(isRecommended: true, catalogRank: 0.9)
    #expect(downloaded.precedes(other))
    #expect(!other.precedes(downloaded))
  }

  @Test
  func `the recommended model is listed above a higher ranked one`() {
    let recommended = Self.key(isRecommended: true, catalogRank: 0.1)
    let other = Self.key(catalogRank: 0.9)
    #expect(recommended.precedes(other))
    #expect(!other.precedes(recommended))
  }

  @Test
  func `rank orders models the flags leave tied`() {
    let higher = Self.key(catalogRank: 0.9)
    let lower = Self.key(catalogRank: 0.1)
    #expect(higher.precedes(lower))
    #expect(!lower.precedes(higher))
    #expect(!higher.precedes(higher))
  }

  @Test
  func `a model the device cannot run is listed below one it can`() {
    let unsupported = Self.key(isSupported: false, isRecommended: true, catalogRank: 0.9)
    let supported = Self.key(catalogRank: 0.1)
    #expect(supported.precedes(unsupported))
    #expect(!unsupported.precedes(supported))
  }

  @Test
  func `a downloaded model the device cannot run is listed below one not yet downloaded`() {
    let unsupported = Self.key(isDownloaded: true, isSupported: false, catalogRank: 0.9)
    let supported = Self.key(catalogRank: 0.1)
    #expect(supported.precedes(unsupported))
    #expect(!unsupported.precedes(supported))
  }

  @Test
  func `the active model stays first even when the device cannot run it`() {
    let active = Self.key(isActive: true, isDownloaded: true, isSupported: false, catalogRank: 0.1)
    let other = Self.key(isDownloaded: true, isRecommended: true, catalogRank: 0.9)
    #expect(active.precedes(other))
    #expect(!other.precedes(active))
  }

  private static func key(
    isActive: Bool = false,
    isDownloaded: Bool = false,
    isSupported: Bool = true,
    isRecommended: Bool = false,
    catalogRank: Double = 0.5,
  ) -> ModelListSortKey {
    ModelListSortKey(
      isActive: isActive,
      isDownloaded: isDownloaded,
      isSupported: isSupported,
      isRecommended: isRecommended,
      catalogRank: catalogRank,
    )
  }
}
