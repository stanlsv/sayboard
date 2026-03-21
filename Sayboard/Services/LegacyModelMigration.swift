// LegacyModelMigration -- One-time migration from HuggingFace-era storage to R2 layout

import Foundation

private let migrationKey = "hasCompletedR2Migration"
private let legacyWhisperKitPathPrefix = "whisperKitModelPath_"
private let legacyParakeetDownloadedPrefix = "parakeetModelDownloaded_"

// MARK: - LegacyModelMigration

enum LegacyModelMigration {

  // MARK: Internal

  /// Migrates existing models from HuggingFace-era storage to `<Application Support>/Models/`.
  static func runIfNeeded() {
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: migrationKey) else { return }

    try? ModelStorageManager.ensureRootExists()
    self.migrateWhisperKitModels(defaults: defaults)
    self.migrateParakeetModels(defaults: defaults)
    self.cleanupLegacyCaches()

    defaults.set(true, forKey: migrationKey)
  }

  // MARK: Private

  private static func migrateWhisperKitModels(defaults: UserDefaults) {
    let fm = FileManager.default
    for variant in ModelVariant.allCases where variant.engine == .whisperKit {
      let key = "\(legacyWhisperKitPathPrefix)\(variant.rawValue)"
      guard let oldPath = defaults.string(forKey: key), !oldPath.isEmpty else { continue }
      let oldURL = URL(fileURLWithPath: oldPath)
      guard fm.fileExists(atPath: oldURL.path) else {
        defaults.removeObject(forKey: key)
        continue
      }

      let newDir = ModelStorageManager.directory(for: variant)
      guard !fm.fileExists(atPath: newDir.path) else {
        defaults.removeObject(forKey: key)
        continue
      }

      do {
        try fm.createDirectory(at: newDir, withIntermediateDirectories: true)
        let destination = newDir.appendingPathComponent(oldURL.lastPathComponent)
        try fm.moveItem(at: oldURL, to: destination)
      } catch {
        let desc = error.localizedDescription
      }
      defaults.removeObject(forKey: key)
    }
  }

  private static func migrateParakeetModels(defaults: UserDefaults) {
    let fm = FileManager.default
    for variant in ModelVariant.allCases where variant.engine == .parakeet {
      let key = "\(legacyParakeetDownloadedPrefix)\(variant.rawValue)"
      guard defaults.bool(forKey: key) else { continue }
      guard let repoFolder = variant.parakeetRepoFolderName else { continue }

      self.moveParakeetModel(variant: variant, repoFolder: repoFolder, fm: fm)
      defaults.removeObject(forKey: key)
    }
  }

  private static func moveParakeetModel(variant: ModelVariant, repoFolder: String, fm: FileManager) {
    guard let appSupportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

    let oldDir = appSupportDir
      .appendingPathComponent("FluidAudio")
      .appendingPathComponent("Models")
      .appendingPathComponent(repoFolder)

    guard fm.fileExists(atPath: oldDir.path) else { return }

    let newDir = ModelStorageManager.directory(for: variant)
    guard !fm.fileExists(atPath: newDir.path) else { return }

    do {
      try fm.createDirectory(at: newDir, withIntermediateDirectories: true)
      let destination = newDir.appendingPathComponent(repoFolder)
      try fm.moveItem(at: oldDir, to: destination)
    } catch {
      let desc = error.localizedDescription
    }
  }

  private static func cleanupLegacyCaches() {
    let fm = FileManager.default

    if let appSupportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
      let hfCacheDir = appSupportDir.appendingPathComponent("huggingface")
      if fm.fileExists(atPath: hfCacheDir.path) {
        try? fm.removeItem(at: hfCacheDir)
      }

      let fluidDir = appSupportDir.appendingPathComponent("FluidAudio")
      if fm.fileExists(atPath: fluidDir.path) {
        let contents = (try? fm.contentsOfDirectory(atPath: fluidDir.path)) ?? []
        if contents.isEmpty {
          try? fm.removeItem(at: fluidDir)
        }
      }
    }

    if let cachesDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
      let fluidCacheDir = cachesDir.appendingPathComponent("FluidAudio")
      if fm.fileExists(atPath: fluidCacheDir.path) {
        try? fm.removeItem(at: fluidCacheDir)
      }
    }
  }
}
