import Testing
@testable import Sayboard

@Suite("BackgroundDownloadManager.shouldEmitProgress")
struct DownloadProgressThrottleTests {

  @Test
  func `the first event for a download always gets through`() {
    #expect(self.manager.shouldEmitProgress(0.004, forKey: "stt/first", now: 0))
  }

  @Test
  func `a repeat of the same whole percent is dropped inside the interval`() {
    let key = "stt/same-percent"
    _ = self.manager.shouldEmitProgress(0.5, forKey: key, now: 0)

    #expect(!self.manager.shouldEmitProgress(0.501, forKey: key, now: self.minIntervalNanos - 1))
  }

  @Test
  func `the same whole percent gets through once the interval has passed`() {
    let key = "stt/slow-link"
    _ = self.manager.shouldEmitProgress(0.5, forKey: key, now: 0)

    #expect(self.manager.shouldEmitProgress(0.501, forKey: key, now: self.minIntervalNanos))
  }

  @Test
  func `a new whole percent gets through inside the interval`() {
    let key = "stt/fast-link"
    _ = self.manager.shouldEmitProgress(0.50, forKey: key, now: 0)

    #expect(self.manager.shouldEmitProgress(0.51, forKey: key, now: 1))
  }

  @Test
  func `the completed transfer gets through, since it is a new percent`() {
    let key = "stt/completion"
    _ = self.manager.shouldEmitProgress(0.996, forKey: key, now: 0)

    #expect(self.manager.shouldEmitProgress(1.0, forKey: key, now: 1))
  }

  @Test
  func `one download does not throttle another`() {
    _ = self.manager.shouldEmitProgress(0.5, forKey: "stt/parakeet", now: 0)

    #expect(self.manager.shouldEmitProgress(0.5, forKey: "llm/qwen", now: 1))
  }

  @Test
  func `a re-enqueued download is not throttled by the previous run`() {
    let key = "stt/retry"
    _ = self.manager.shouldEmitProgress(0.5, forKey: key, now: 0)
    self.manager.lastProgress[key] = nil

    #expect(self.manager.shouldEmitProgress(0.5, forKey: key, now: 1))
  }

  private let minIntervalNanos: UInt64 = 100_000_000
  private let manager = BackgroundDownloadManager.shared

}
