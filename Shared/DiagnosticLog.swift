
import Foundation

enum DiagnosticLog {

  static var fileURL: URL? {
    AppGroup.containerURL?.appendingPathComponent(fileName)
  }

  static func write(_ message: @autoclosure () -> String) {
    #if DEBUG
    self.queue.sync {
      let line = "\(self.timestamp()) [\(self.processTag)] \(message())\n"
      guard let url = fileURL, let data = line.data(using: .utf8) else { return }
      self.rotateIfNeeded(url: url)
      guard let handle = try? FileHandle(forWritingTo: url) else {
        try? data.write(to: url, options: [.completeFileProtectionUntilFirstUserAuthentication])
        return
      }
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
    }
    #endif
  }

  static func clear() {
    #if DEBUG
    self.queue.sync {
      guard let url = fileURL else { return }
      try? Data().write(to: url, options: [.completeFileProtectionUntilFirstUserAuthentication])
    }
    #endif
  }

  private static let fileName = "ios27-diagnostic.log"

  private static let maxBytes = 512 * 1024

  private static let queue = DispatchQueue(label: "app.sayboard.diagnosticLog")

  private static let processTag = ProcessInfo.processInfo.processName

  private static let formatter: DateFormatter = {
    let value = DateFormatter()
    value.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return value
  }()

  private static func timestamp() -> String {
    self.formatter.string(from: Date())
  }

  private static func rotateIfNeeded(url: URL) {
    guard
      let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
      size > maxBytes
    else { return }
    try? Data().write(to: url, options: [.completeFileProtectionUntilFirstUserAuthentication])
  }
}
