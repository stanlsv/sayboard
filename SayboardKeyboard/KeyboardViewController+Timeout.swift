// KeyboardViewController+Timeout -- Processing timeout with LLM result polling

import UIKit

// MARK: - Processing Timeout

extension KeyboardViewController {

  static let processingCheckInterval: TimeInterval = 5
  static let processingHardTimeout: TimeInterval = 60

  func cancelProcessingTimeout() {
    self.processingTimeoutTimer?.invalidate()
    self.processingTimeoutTimer = nil
    self.processingStartTime = nil
    self.receivedPingDuringProcessing = false
  }

  func startProcessingTimeout() {
    if self.processingStartTime == nil {
      self.processingStartTime = Date()
    }
    // Ping the main app and reset the flag. If alive, it responds with
    // sessionStarted which sets receivedPingDuringProcessing = true.
    self.receivedPingDuringProcessing = false
    self.pingMainAppForSessionStatus()

    self.processingTimeoutTimer?.invalidate()
    self.processingTimeoutTimer = Timer.scheduledTimer(
      withTimeInterval: Self.processingCheckInterval,
      repeats: false,
    ) { [weak self] _ in
      DispatchQueue.main.async {
        guard let self, self.keyboardState.isProcessing || self.keyboardState.isLLMProcessing else { return }

        let elapsed = self.processingStartTime.map {
          Date().timeIntervalSince($0)
        } ?? 0

        if self.receivedPingDuringProcessing {
          // App responded — it is alive
          if elapsed < Self.processingHardTimeout {
            // Poll for LLM result in case completion notification was lost
            if self.keyboardState.isLLMProcessing {
              self.checkForPendingLLMResult()
            }
            if !self.keyboardState.isProcessing, !self.keyboardState.isLLMProcessing {
              self.cancelProcessingTimeout()
              return
            }
            self.startProcessingTimeout()
          } else {
            self.insertTranscribedText()
            self.checkForPendingLLMResult()
            self.resetProcessingState()
          }
        } else {
          // No ping response — app is dead
          self.insertTranscribedText()
          self.checkForPendingLLMResult()
          self.resetProcessingState()
        }
      }
    }
  }

  func resetProcessingState() {
    self.cancelProcessingTimeout()
    self.keyboardState.stopLevelPolling()
    self.keyboardState.isProcessing = false
    self.keyboardState.isRecording = false
    self.keyboardState.isSessionActive = false
    self.keyboardState.isLLMProcessing = false
    if !self.isPerformingHistoryNavigation {
      self.keyboardState.clearLLMHistory()
    }
    // Clear shared flags so the next keyboard appearance does not see stale state
    let settings = SharedSettings()
    settings.isSessionActive = false
    settings.isRecording = false
    settings.isLLMProcessing = false
    settings.synchronize()
  }
}
