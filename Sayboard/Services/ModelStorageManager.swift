// ModelStorageManager -- Manages on-disk model storage under <Application Support>/Models/

import Foundation

// MARK: - ModelStorageManager

enum ModelStorageManager {

  // MARK: Internal

  static var modelsRoot: URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return appSupport.appendingPathComponent("Models", isDirectory: true)
  }

  /// Returns the top-level directory for a given variant: `<Application Support>/Models/<variant.rawValue>/`
  static func directory(for variant: ModelVariant) -> URL {
    self.modelsRoot.appendingPathComponent(variant.rawValue, isDirectory: true)
  }

  /// Checks whether a model variant has been downloaded by verifying its directory exists
  /// and contains the expected model files for its engine type.
  static func isDownloaded(_ variant: ModelVariant) -> Bool {
    let dir = self.directory(for: variant)
    switch variant.engine {
    case .whisperKit, .parakeet:
      return self.containsMLModel(at: dir)
    case .moonshine:
      return self.containsONNXModel(at: dir)
    }
  }

  /// Deletes all files for a given variant.
  /// The CoreML compilation cache is left intact so remaining models don't need recompilation.
  /// Users can clear it manually via Settings > About > Clear Model Cache.
  static func delete(_ variant: ModelVariant) throws {
    let dir = self.directory(for: variant)
    guard FileManager.default.fileExists(atPath: dir.path) else { return }
    try FileManager.default.removeItem(at: dir)
  }

  /// Creates the root Models directory if it does not exist and excludes it from iCloud backup.
  static func ensureRootExists() throws {
    var root = self.modelsRoot
    if !FileManager.default.fileExists(atPath: root.path) {
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try root.setResourceValues(values)
  }

  /// Returns the total disk usage of all downloaded models in bytes.
  static func totalDiskUsage() -> Int64 {
    let root = self.modelsRoot
    guard FileManager.default.fileExists(atPath: root.path) else { return 0 }
    guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey]) else {
      return 0
    }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
        total += Int64(size)
      }
    }
    return total
  }

  /// Removes the CoreML compiled model cache and re-establishes the persistent symlink.
  ///
  /// Clears the persistent directory contents first, then removes any legacy real directory
  /// at the Caches path, and finally recreates the empty persistent structure with symlink.
  static func clearCompiledModelCache() {
    let fm = FileManager.default
    var totalCleared: Int64 = 0

    // 1. Clear persistent directory contents.
    if
      let persistentURL = self.persistentCoreMLCacheURL(),
      fm.fileExists(atPath: persistentURL.path)
    {
      let size = Self.directorySize(at: persistentURL)
      totalCleared += size
      do {
        try fm.removeItem(at: persistentURL)
      } catch {
        // no-op
      }
    }

    // 2. Remove any real (non-symlink) directory at the Caches path (pre-migration legacy).
    if let cachesURL = self.compiledModelCacheURL() {
      let cachesPath = cachesURL.path
      if
        let attrs = try? fm.attributesOfItem(atPath: cachesPath),
        let fileType = attrs[.type] as? FileAttributeType,
        fileType != .typeSymbolicLink
      {
        let size = Self.directorySize(at: cachesURL)
        totalCleared += size
        do {
          try fm.removeItem(at: cachesURL)
        } catch {
          // no-op
        }
      } else if
        let attrs = try? fm.attributesOfItem(atPath: cachesPath),
        let fileType = attrs[.type] as? FileAttributeType,
        fileType == .typeSymbolicLink
      {
        // Remove existing symlink so ensurePersistentCoreMLCache() can recreate it cleanly.
        try? fm.removeItem(atPath: cachesPath)
      }
    }

    if totalCleared > 0 {
    } else { }

    // 3. Re-establish empty persistent structure with symlink.
    self.ensurePersistentCoreMLCache()
  }

  /// Returns the size of the CoreML compiled model cache in bytes.
  /// Reads from the persistent location first, falls back to the Caches path for pre-migration state.
  static func compiledModelCacheSize() -> Int64 {
    if
      let persistentURL = self.persistentCoreMLCacheURL(),
      FileManager.default.fileExists(atPath: persistentURL.path)
    {
      return self.directorySize(at: persistentURL)
    }
    guard let cachesURL = self.compiledModelCacheURL() else { return 0 }
    guard FileManager.default.fileExists(atPath: cachesURL.path) else { return 0 }
    return self.directorySize(at: cachesURL)
  }

  /// Symlinks the CoreML e5rt cache directory from `Library/Caches/` to `Library/Application Support/`
  /// so that compiled models survive app kills and iOS cache purges.
  ///
  /// CoreML follows symlinks transparently. The persistent directory is excluded from iCloud backup.
  static func ensurePersistentCoreMLCache() {
    guard
      let cachesURL = self.compiledModelCacheURL(),
      let persistentURL = self.persistentCoreMLCacheURL()
    else {
      return
    }

    do {
      let alreadyValid = try self.resolveExistingCachePath(
        cachesURL: cachesURL,
        persistentURL: persistentURL,
      )
      guard !alreadyValid else { return }
      try self.createCacheSymlink(cachesURL: cachesURL, persistentURL: persistentURL)
    } catch {
      // no-op
    }
  }

  // MARK: Private

  private static let e5rtCacheDirName = "com.apple.e5rt.e5bundlecache"
  private static let persistentCacheDirName = "CoreMLCache"

  private static var effectiveBundleId: String {
    Bundle.main.bundleIdentifier ?? "app.sayboard"
  }

  /// Inspects the Caches path and migrates any existing data to the persistent location.
  /// Returns `true` if a valid symlink already exists (no further action needed).
  private static func resolveExistingCachePath(cachesURL: URL, persistentURL: URL) throws -> Bool {
    let fm = FileManager.default
    let cachesPath = cachesURL.path

    // Determine current state of the Caches path (symlink, directory, or absent).
    let attrs = try? fm.attributesOfItem(atPath: cachesPath)
    let fileType = attrs?[.type] as? FileAttributeType
    let cachesIsSymlink = fileType == .typeSymbolicLink
    let cachesExists = attrs != nil
    let persistentExists = fm.fileExists(atPath: persistentURL.path)

    // If symlink already points to the right place, just ensure target exists.
    if cachesIsSymlink {
      let destination = try fm.destinationOfSymbolicLink(atPath: cachesPath)
      if destination == persistentURL.path {
        if !persistentExists {
          try fm.createDirectory(at: persistentURL, withIntermediateDirectories: true)
        }
        return true
      }
      // Symlink points somewhere unexpected — remove and recreate.
      try fm.removeItem(atPath: cachesPath)
    }

    // If a real directory exists at the Caches path, migrate it.
    if !cachesIsSymlink, cachesExists {
      if persistentExists {
        try fm.removeItem(at: cachesURL)
      } else {
        try fm.createDirectory(at: persistentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: cachesURL, to: persistentURL)
      }
    }

    return false
  }

  /// Creates the symlink from Caches to Application Support and excludes from backup.
  private static func createCacheSymlink(cachesURL: URL, persistentURL: URL) throws {
    let fm = FileManager.default

    if !fm.fileExists(atPath: persistentURL.path) {
      try fm.createDirectory(at: persistentURL, withIntermediateDirectories: true)
    }

    // Ensure Caches parent directory exists (iOS may have purged it).
    let cachesParent = cachesURL.deletingLastPathComponent()
    if !fm.fileExists(atPath: cachesParent.path) {
      try fm.createDirectory(at: cachesParent, withIntermediateDirectories: true)
    }

    try fm.createSymbolicLink(at: cachesURL, withDestinationURL: persistentURL)

    var resourceURL = persistentURL
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try resourceURL.setResourceValues(values)
  }

  /// Caches path: `Library/Caches/<bundleID>/com.apple.e5rt.e5bundlecache/`
  /// This is where CoreML writes its compiled model cache by default.
  private static func compiledModelCacheURL() -> URL? {
    guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      return nil
    }
    return cachesDir
      .appendingPathComponent(self.effectiveBundleId, isDirectory: true)
      .appendingPathComponent(self.e5rtCacheDirName, isDirectory: true)
  }

  /// Persistent path: `Library/Application Support/<bundleID>/CoreMLCache/`
  private static func persistentCoreMLCacheURL() -> URL? {
    guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else {
      return nil
    }
    return appSupportDir
      .appendingPathComponent(self.effectiveBundleId, isDirectory: true)
      .appendingPathComponent(self.persistentCacheDirName, isDirectory: true)
  }

  /// Returns the total size of a directory in bytes.
  private static func directorySize(at url: URL) -> Int64 {
    guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
      return 0
    }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
        total += Int64(size)
      }
    }
    return total
  }

  /// Recursively checks whether a directory (or any subdirectory) contains an `.ort` model file.
  private static func containsONNXModel(at url: URL) -> Bool {
    guard FileManager.default.fileExists(atPath: url.path) else { return false }
    guard
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [],
      )
    else {
      return false
    }
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "ort" {
      return true
    }
    return false
  }

  /// Recursively checks whether a directory (or any subdirectory) contains an `.mlmodelc` bundle.
  private static func containsMLModel(at url: URL) -> Bool {
    guard FileManager.default.fileExists(atPath: url.path) else { return false }
    guard
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [],
      )
    else {
      return false
    }
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "mlmodelc" {
      return true
    }
    return false
  }
}
