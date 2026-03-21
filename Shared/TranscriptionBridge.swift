import Foundation

// MARK: - TranscriptionBridge

// Main app writes transcribed text to a shared file in the App Group container.
// Keyboard extension reads the file and inserts text into the active text field.
// Darwin notifications signal when new transcription is available.

struct TranscriptionBridge: Sendable {

  // MARK: Internal

  static func writeTranscription(_ text: String) {
    guard let url = transcriptionFileURL else { return }
    do {
      try Data(text.utf8).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    } catch {
      // no-op
    }
    self.postDarwinNotification(DarwinNotificationName.transcriptionReady)
  }

  static func readTranscription() -> String? {
    guard let url = transcriptionFileURL else { return nil }
    return try? String(contentsOf: url, encoding: .utf8)
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

  // MARK: Private

  private static let transcriptionFileName = "transcription.txt"

  private static var transcriptionFileURL: URL? {
    AppGroup.containerURL?.appendingPathComponent(transcriptionFileName)
  }
}

// MARK: - DarwinNotificationObserver

// CFNotificationCenter holds an unretained pointer to the observer. We use
// passRetained/release to ensure `self` stays alive while CF holds the pointer.
// Callers MUST call `stopObserving()` before releasing the last strong reference.
// If they forget, the object intentionally leaks (via the +1 retain) rather than
// allowing a use-after-free in the CF callback.
// swiftlint:disable:next no_unchecked_sendable
final class DarwinNotificationObserver: @unchecked Sendable {

  // MARK: Lifecycle

  init(name: String, callback: @escaping () -> Void) {
    self.name = name
    self.callback = callback

    let center = CFNotificationCenterGetDarwinNotifyCenter()
    // +1 retain: CF now holds a strong reference via the opaque pointer
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
    // Safety net: remove observer if stopObserving() was never called.
    // We intentionally do NOT release here — if we reach deinit without
    // stopObserving(), the extra retain was already consumed elsewhere.
    if self.isObserving {
      let center = CFNotificationCenterGetDarwinNotifyCenter()
      let observer = Unmanaged.passUnretained(self).toOpaque()
      CFNotificationCenterRemoveObserver(center, observer, CFNotificationName(self.name as CFString), nil)
    }
  }

  // MARK: Internal

  func stopObserving() {
    guard self.isObserving else { return }
    self.isObserving = false

    let center = CFNotificationCenterGetDarwinNotifyCenter()
    let observer = Unmanaged.passUnretained(self).toOpaque()
    CFNotificationCenterRemoveObserver(center, observer, CFNotificationName(self.name as CFString), nil)

    // Balance the +1 retain from init — CF no longer holds the pointer
    Unmanaged.passUnretained(self).release()
  }

  // MARK: Private

  private let name: String
  private let callback: () -> Void
  private var isObserving = false
}
