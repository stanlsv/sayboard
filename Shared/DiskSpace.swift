import Foundation

enum DiskSpace {

  static let lowSpaceThresholdBytes = 10_000_000_000

  static func availableBytes() -> Int? {
    let url = URL(fileURLWithPath: NSHomeDirectory())
    let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
    return values?.volumeAvailableCapacity
  }

  static func isLow() -> Bool {
    guard let available = availableBytes() else { return false }
    return available < self.lowSpaceThresholdBytes
  }
}
