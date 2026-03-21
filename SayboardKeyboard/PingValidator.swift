import Foundation

// MARK: - PingValidator

// PingValidator -- Detects stale isSessionActive flags after the main app is killed.
//
// On viewWillAppear / hostDidEnterForeground, the keyboard pings the main app
// via Darwin notification. If the app is alive, it responds with sessionStarted
// (which calls `cancel()`). If no response arrives within `timeout` seconds,
// the session flags are stale and must be cleared.

@MainActor
final class PingValidator {

  // MARK: Internal

  func startIfNeeded(for keyboardState: KeyboardState) {
    guard keyboardState.isSessionActive else { return }
    self.responseReceived = false
    self.timer?.invalidate()
    self.timer = Timer.scheduledTimer(
      withTimeInterval: Self.timeout,
      repeats: false,
    ) { [weak self] _ in
      DispatchQueue.main.async {
        guard let self, !self.responseReceived else { return }
        guard keyboardState.isSessionActive else { return }
        keyboardState.isSessionActive = false
        keyboardState.isRecording = false
        let settings = SharedSettings()
        settings.isSessionActive = false
        settings.isRecording = false
        settings.synchronize()
      }
    }
  }

  func cancel() {
    self.responseReceived = true
    self.timer?.invalidate()
    self.timer = nil
  }

  // MARK: Private

  private static let timeout: TimeInterval = 1

  private var timer: Timer?
  private var responseReceived = false
}
