import Foundation

@MainActor
final class PingValidator {

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

  private static let timeout: TimeInterval = 1

  private var timer: Timer?
  private var responseReceived = false
}
