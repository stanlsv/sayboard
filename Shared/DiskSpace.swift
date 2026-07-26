import Foundation

// DiskSpace -- Shared free-storage check used by both the app and the keyboard.
//
// iOS purges Library/Caches (including Core ML's compiled-model / ANE cache) under
// storage pressure, which forces a slow model rebuild on next load. We surface a
// warning before that happens so the user understands the cause.

enum DiskSpace {

  /// Free space below this is treated as "low". Set generously (proactive heads-up):
  /// there is no reliable signal for when iOS will purge the Core ML compiled-model
  /// cache, so we warn early rather than try to catch the exact moment.
  static let lowSpaceThresholdBytes = 10_000_000_000

  /// Actual free space in bytes, or nil if it can't be read.
  ///
  /// Uses `volumeAvailableCapacity` (real free space) rather than
  /// `volumeAvailableCapacityForImportantUsage`, which counts purgeable space the
  /// system could reclaim and therefore stays high exactly when caches are being
  /// purged -- the very situation we need to detect.
  static func availableBytes() -> Int? {
    let url = URL(fileURLWithPath: NSHomeDirectory())
    let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
    return values?.volumeAvailableCapacity
  }

  /// True when free space is below `lowSpaceThresholdBytes`.
  static func isLow() -> Bool {
    guard let available = availableBytes() else { return false }
    return available < self.lowSpaceThresholdBytes
  }
}
