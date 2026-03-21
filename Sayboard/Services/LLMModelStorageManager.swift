// LLMModelStorageManager -- Manages on-disk LLM model storage under <Application Support>/LLMModels/

import Foundation

// MARK: - LLMModelStorageManager

enum LLMModelStorageManager {

  static var modelsRoot: URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return appSupport.appendingPathComponent("LLMModels", isDirectory: true)
  }

  static func directory(for variant: LLMModelVariant) -> URL {
    self.modelsRoot.appendingPathComponent(variant.rawValue, isDirectory: true)
  }

  static func isDownloaded(_ variant: LLMModelVariant) -> Bool {
    self.modelFileURL(for: variant) != nil
  }

  /// Returns the URL of the .gguf file for a downloaded variant, or nil if not found.
  static func modelFileURL(for variant: LLMModelVariant) -> URL? {
    let dir = self.directory(for: variant)
    let ggufURL = dir.appendingPathComponent(variant.ggufFileName)
    if FileManager.default.fileExists(atPath: ggufURL.path) {
      return ggufURL
    }
    // Search recursively for any .gguf file in case of nested extraction
    guard
      let enumerator = FileManager.default.enumerator(
        at: dir,
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles,
      )
    else {
      return nil
    }
    for case let fileURL as URL in enumerator where fileURL.pathExtension == "gguf" {
      return fileURL
    }
    return nil
  }

  static func delete(_ variant: LLMModelVariant) throws {
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
}
