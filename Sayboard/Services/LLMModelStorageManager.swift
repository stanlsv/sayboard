
import Foundation

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

  static func modelFileURL(for variant: LLMModelVariant) -> URL? {
    let dir = self.directory(for: variant)
    let ggufURL = dir.appendingPathComponent(variant.ggufFileName)
    if FileManager.default.fileExists(atPath: ggufURL.path) {
      return ggufURL
    }
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

  static func removeOrphanedDirectories() {
    let fm = FileManager.default
    let root = self.modelsRoot
    guard fm.fileExists(atPath: root.path) else { return }

    let known = Set(LLMModelVariant.allCases.map(\.rawValue))
    let contents: [URL]
    do {
      contents = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
    } catch {
      return
    }

    for url in contents where !known.contains(url.lastPathComponent) {
      do {
        try fm.removeItem(at: url)
      } catch { }
    }
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
