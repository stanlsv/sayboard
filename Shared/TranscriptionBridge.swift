import Foundation

struct TranscriptionBridge: Sendable {

  static func writeTranscription(_ text: String) {
    guard let url = transcriptionFileURL else {
      return
    }
    do {
      try Data(text.utf8).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
      DiagnosticLog.write("bridge: wrote \(text.count) chars")
    } catch {
      DiagnosticLog.write("bridge: WRITE FAILED: \(error.localizedDescription)")
    }
    self.postDarwinNotification(DarwinNotificationName.transcriptionReady)
  }

  static func readTranscription() -> String? {
    guard let url = transcriptionFileURL else {
      return nil
    }
    do {
      let text = try String(contentsOf: url, encoding: .utf8)
      DiagnosticLog.write("bridge: read \(text.count) chars")
      return text
    } catch {
      DiagnosticLog.write("bridge: READ FAILED: \(error.localizedDescription)")
      return nil
    }
  }

  static func clearTranscription() {
    guard let url = transcriptionFileURL else { return }
    try? Data().write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
  }

  static func postDarwinNotification(_ name: String) {
    let center = CFNotificationCenterGetDarwinNotifyCenter()
    CFNotificationCenterPostNotification(center, CFNotificationName(name as CFString), nil, nil, true)
  }

  static func observeDarwinNotification(_ name: String, callback: @escaping () -> Void) -> DarwinNotificationObserver {
    DarwinNotificationObserver(name: name, callback: callback)
  }

  private static let transcriptionFileName = "transcription.txt"

  private static var transcriptionFileURL: URL? {
    AppGroup.containerURL?.appendingPathComponent(transcriptionFileName)
  }
}

final class DarwinNotificationObserver: @unchecked Sendable {

  init(name: String, callback: @escaping () -> Void) {
    self.name = name
    self.callback = callback

    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let observer = Unmanaged.passRetained(self).toOpaque()

    CFNotificationCenterAddObserver(
      center,
      observer,
      { _, observer, _, _, _ in
        guard let observer else { return }
        let obj = Unmanaged<DarwinNotificationObserver>.fromOpaque(observer).takeUnretainedValue()
        obj.callback()
      },
      name as CFString,
      nil,
      .deliverImmediately,
    )
    self.isObserving = true
  }

  deinit {
    if self.isObserving {
      let center = CFNotificationCenterGetDarwinNotifyCenter()
      let observer = Unmanaged.passUnretained(self).toOpaque()
      CFNotificationCenterRemoveObserver(center, observer, CFNotificationName(self.name as CFString), nil)
    }
  }

  func stopObserving() {
    guard self.isObserving else { return }
    self.isObserving = false

    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let observer = Unmanaged.passUnretained(self).toOpaque()
    CFNotificationCenterRemoveObserver(center, observer, CFNotificationName(self.name as CFString), nil)

    Unmanaged.passUnretained(self).release()
  }

  private let name: String
  private let callback: () -> Void
  private var isObserving = false
}
