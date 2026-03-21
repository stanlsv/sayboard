import Foundation
import os

// AudioLevelBridge -- Cross-process audio level transport via App Group UserDefaults.
// Writer (main app): audio thread stores level in a thread-safe lock,
// main thread timer flushes to UserDefaults.
// Reader (keyboard): polls UserDefaults at display refresh rate.

// MARK: - AudioLevelBridge

// Thread-safe: pendingLevel uses OSAllocatedUnfairLock; SharedSettings wraps
// UserDefaults which is documented thread-safe. @unchecked because SharedSettings
// is not formally Sendable.
// swiftlint:disable:next no_unchecked_sendable
final class AudioLevelBridge: @unchecked Sendable {

  // MARK: Lifecycle

  init(mode: Mode) {
    self.mode = mode
  }

  // MARK: Internal

  enum Mode {
    case writer
    case reader
  }

  /// Stores level in thread-safe memory. Safe to call from real-time audio thread.
  func writeLevel(_ level: Float) {
    self.pendingLevel.withLock { $0 = level }
  }

  /// Flushes pending level to UserDefaults. Call from main thread timer.
  func flushToDefaults() {
    let level = self.pendingLevel.withLock { $0 }
    SharedSettings().audioLevel = level
  }

  /// Reads level from UserDefaults after synchronizing cross-process changes.
  func readLevel() -> Float {
    let settings = SharedSettings()
    settings.synchronize()
    return settings.audioLevel
  }

  // MARK: Private

  private let mode: Mode
  private let pendingLevel = OSAllocatedUnfairLock<Float>(initialState: 0)
}
