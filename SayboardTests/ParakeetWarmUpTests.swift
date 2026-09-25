import Testing
@testable import Sayboard

private let pagedInBytes: UInt64 = 1_250_000_000
private let driftedBytes: UInt64 = 1_190_000_000
private let atMarginBytes: UInt64 = 1_150_000_000
private let justPastMarginBytes: UInt64 = 1_149_999_999
private let grownBytes: UInt64 = 1_300_000_000
private let evictedBytes: UInt64 = 770_000_000

@Suite("ParakeetTranscriptionService.needsWarmUp")
struct ParakeetWarmUpTests {

  @Test
  func `a model with no run since its load warms up`() {
    #expect(ParakeetTranscriptionService.needsWarmUp(pagedInBytes: nil, residentBytes: grownBytes))
  }

  @Test
  func `resident memory that drifted less than the margin skips the warm-up`() {
    #expect(!ParakeetTranscriptionService.needsWarmUp(pagedInBytes: pagedInBytes, residentBytes: driftedBytes))
  }

  @Test
  func `resident memory above the sample skips the warm-up`() {
    #expect(!ParakeetTranscriptionService.needsWarmUp(pagedInBytes: pagedInBytes, residentBytes: grownBytes))
  }

  @Test
  func `a shortfall of exactly the margin skips the warm-up`() {
    #expect(!ParakeetTranscriptionService.needsWarmUp(pagedInBytes: pagedInBytes, residentBytes: atMarginBytes))
  }

  @Test
  func `a shortfall just past the margin warms up`() {
    #expect(ParakeetTranscriptionService.needsWarmUp(pagedInBytes: pagedInBytes, residentBytes: justPastMarginBytes))
  }

  @Test
  func `evicted pages warm up`() {
    #expect(ParakeetTranscriptionService.needsWarmUp(pagedInBytes: pagedInBytes, residentBytes: evictedBytes))
  }
}
