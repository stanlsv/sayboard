
import Foundation

enum ModelDiskReserve {

  static let headroom = 1.10

  static let unmeasuredSpeechMultiplier = 2.6

  static let unattendedFloorBytes: Int64 = 2_000_000_000

  static func requiredBytes(peak: Int64) -> Int64 {
    Int64(Double(peak) * self.headroom)
  }

  static func availableBytes() -> Int64? {
    do {
      let appSupportURL = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false,
      )
      let values = try appSupportURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      return values.volumeAvailableCapacityForImportantUsage
    } catch {
      return nil
    }
  }
}
