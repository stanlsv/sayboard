
import FluidAudio
import Foundation

private let jointV3BundleName = ModelNames.ASR.jointV3File

enum ParakeetV3JointMigration {

  static func runIfNeeded() {
    let variant = ModelVariant.parakeetV3
    let settings = SharedSettings()
    guard ModelStorageManager.isDownloaded(variant) else { return }

    let directory = ModelStorageManager.directory(for: variant)
    guard !self.containsJointV3(at: directory) else {
      settings.parakeetV3NeedsRedownload = false
      return
    }

    DiagnosticLog.write("migration: deleting pre-JointDecisionv3 Parakeet v3 model")
    do {
      try ModelStorageManager.delete(variant)
      settings.parakeetV3NeedsRedownload = true
      if settings.selectedVariant == variant {
        settings.hasUsableModel = false
      }
    } catch {
      DiagnosticLog.write("migration: FAILED to delete Parakeet v3 — \(error)")
    }
  }

  private static func containsJointV3(at url: URL) -> Bool {
    guard
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: nil,
        options: [],
      )
    else {
      return false
    }
    for case let fileURL as URL in enumerator where fileURL.lastPathComponent == jointV3BundleName {
      return true
    }
    return false
  }
}
