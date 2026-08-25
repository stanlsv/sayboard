
import Foundation

enum ModelStorageManager {

  static var modelsRoot: URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return appSupport.appendingPathComponent("Models", isDirectory: true)
  }

  static func directory(for variant: ModelVariant) -> URL {
    self.modelsRoot.appendingPathComponent(variant.rawValue, isDirectory: true)
  }

  static func isDownloaded(_ variant: ModelVariant) -> Bool {
    let dir = self.directory(for: variant)
    switch variant.engine {
    case .whisperKit, .parakeet:
      return self.containsMLModel(at: dir)
    case .moonshine:
      return self.containsONNXModel(at: dir)
    }
  }

  static func delete(_ variant: ModelVariant) throws {
    let dir = self.directory(for: variant)
    guard FileManager.default.fileExists(atPath: dir.path) else { return }
    try FileManager.default.removeItem(at: dir)
  }

  static func ensureRootExists() throws {
    var root = self.modelsRoot
    if !FileManager.default.fileExists(atPath: root.path) {
      try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try root.setResourceValues(values)
  }

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

  static func clearCompiledModelCache() {
    let fm = FileManager.default
    var totalCleared: Int64 = 0

    if
      let persistentURL = self.persistentCoreMLCacheURL(),
      fm.fileExists(atPath: persistentURL.path)
    {
      let size = Self.directorySize(at: persistentURL)
      totalCleared += size
      do {
        try fm.removeItem(at: persistentURL)
      } catch { }
    }

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
        } catch { }
      } else if
        let attrs = try? fm.attributesOfItem(atPath: cachesPath),
        let fileType = attrs[.type] as? FileAttributeType,
        fileType == .typeSymbolicLink
      {
        try? fm.removeItem(atPath: cachesPath)
      }
    }

    if totalCleared > 0 {
    } else { }

    self.ensurePersistentCoreMLCache()
  }

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
    } catch { }
  }

  private static let e5rtCacheDirName = "com.apple.e5rt.e5bundlecache"
  private static let persistentCacheDirName = "CoreMLCache"

  private static var effectiveBundleId: String {
    Bundle.main.bundleIdentifier ?? "app.sayboard"
  }

  private static func resolveExistingCachePath(cachesURL: URL, persistentURL: URL) throws -> Bool {
    let fm = FileManager.default
    let cachesPath = cachesURL.path

    let attrs = try? fm.attributesOfItem(atPath: cachesPath)
    let fileType = attrs?[.type] as? FileAttributeType
    let cachesIsSymlink = fileType == .typeSymbolicLink
    let cachesExists = attrs != nil
    let persistentExists = fm.fileExists(atPath: persistentURL.path)

    if cachesIsSymlink {
      let destination = try fm.destinationOfSymbolicLink(atPath: cachesPath)
      if destination == persistentURL.path {
        if !persistentExists {
          try fm.createDirectory(at: persistentURL, withIntermediateDirectories: true)
        }
        return true
      }
      try fm.removeItem(atPath: cachesPath)
    }

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

  private static func createCacheSymlink(cachesURL: URL, persistentURL: URL) throws {
    let fm = FileManager.default

    if !fm.fileExists(atPath: persistentURL.path) {
      try fm.createDirectory(at: persistentURL, withIntermediateDirectories: true)
    }

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

  private static func compiledModelCacheURL() -> URL? {
    guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      return nil
    }
    return cachesDir
      .appendingPathComponent(self.effectiveBundleId, isDirectory: true)
      .appendingPathComponent(self.e5rtCacheDirName, isDirectory: true)
  }

  private static func persistentCoreMLCacheURL() -> URL? {
    guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else {
      return nil
    }
    return appSupportDir
      .appendingPathComponent(self.effectiveBundleId, isDirectory: true)
      .appendingPathComponent(self.persistentCacheDirName, isDirectory: true)
  }

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
