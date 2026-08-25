import Foundation
import os

final class AudioLevelBridge: @unchecked Sendable {

  init(mode: Mode) {
    self.mode = mode
  }

  enum Mode {
    case writer
    case reader
  }

  func writeLevel(_ level: Float) {
    self.pendingLevel.withLock { $0 = level }
  }

  func flushToDefaults() {
    let level = self.pendingLevel.withLock { $0 }
    SharedSettings().audioLevel = level
  }

  func readLevel() -> Float {
    let settings = SharedSettings()
    settings.synchronize()
    return settings.audioLevel
  }

  private let mode: Mode
  private let pendingLevel = OSAllocatedUnfairLock<Float>(initialState: 0)
}
