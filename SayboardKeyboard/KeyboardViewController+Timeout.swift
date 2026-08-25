
import UIKit

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
          if elapsed < Self.processingHardTimeout {
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
    let settings = SharedSettings()
    settings.isSessionActive = false
    settings.isRecording = false
    settings.isLLMProcessing = false
    settings.synchronize()
  }
}
