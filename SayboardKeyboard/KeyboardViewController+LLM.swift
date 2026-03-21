// KeyboardViewController+LLM -- LLM processing observers and text replacement

import NaturalLanguage

import UIKit

// MARK: - LLM Processing

extension KeyboardViewController {

  // MARK: Internal

  func setupLLMObservers() {
    self.llmStartedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.llmProcessingStarted
    ) { [weak self] in
      DispatchQueue.main.async {
        self?.keyboardState.isLLMProcessing = true
      }
    }

    self.llmCompleteObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.llmProcessingComplete
    ) { [weak self] in
      DispatchQueue.main.async {
        self?.insertLLMResult()
      }
    }

    self.llmFailedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.llmProcessingFailed
    ) { [weak self] in
      DispatchQueue.main.async {
        self?.insertPendingAutoActionFallback()
        self?.keyboardState.isLLMProcessing = false
        self?.keyboardState.isProcessing = false
      }
    }
  }

  /// Attempts to auto-apply the default LLM action.
  /// - Parameter directText: If provided, text is sent directly to LLM without inserting into the document.
  /// - Returns: `true` if auto-action was triggered, `false` otherwise.
  @discardableResult
  func autoApplyLLMIfNeeded(directText: String? = nil) -> Bool {
    guard self.keyboardState.llmEnabled else { return false }
    guard self.keyboardState.hasUsableLLMModel else { return false }
    guard !self.keyboardState.isLLMProcessing else { return false }

    let selection = self.keyboardState.defaultLLMActionSelection
    guard selection.isSet else { return false }

    let resolved = selection.resolve(
      defaultAction: .rewrite,
      customPrompts: self.keyboardState.llmCustomPrompts,
      disabledActions: self.keyboardState.disabledLLMActions,
    )

    guard let resolved else {
      // Custom prompt deleted or action disabled — reset to .none
      self.keyboardState.defaultLLMActionSelection = .none
      SharedSettings().defaultLLMActionSelection = .none
      return false
    }

    self.requestLLMProcessing(action: resolved.action, customPromptId: resolved.customPromptId, directText: directText)
    return true
  }

  func requestLLMProcessing(action: LLMAction, customPromptId: UUID?, directText: String? = nil) {
    guard !self.keyboardState.isLLMProcessing else {
      return
    }

    let inputText: String
    if let directText {
      // Text passed directly (auto-action): not inserted into document yet
      inputText = directText
      self.llmOriginalTextLength = 0
      self.pendingAutoActionText = directText
    } else {
      // Text already in document: read from cursor position
      let beforeText = textDocumentProxy.documentContextBeforeInput ?? ""
      let trimmedText = beforeText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedText.isEmpty else {
        self.keyboardState.llmError = .noTextBeforeCursor
        self.updateKeyboardHeight(actionBarVisible: false)
        return
      }
      inputText = beforeText
      self.llmOriginalTextLength = beforeText.count
      self.pendingAutoActionText = nil
    }

    self.keyboardState.isLLMProcessing = true

    // Seed or maintain LLM text history
    if self.keyboardState.llmTextHistory.isEmpty {
      self.keyboardState.llmTextHistory = [inputText]
      self.keyboardState.llmHistoryIndex = 0
    } else {
      // Truncate forward history if user undid then triggers new LLM action
      let idx = self.keyboardState.llmHistoryIndex
      self.keyboardState.llmTextHistory = Array(self.keyboardState.llmTextHistory.prefix(idx + 1))
    }

    // Detect language from the text itself using NLLanguageRecognizer
    let language = Self.detectLanguage(from: inputText)

    // Ensure session token exists before signaling main app
    let settings = SharedSettings()
    if settings.dictationSessionToken == nil {
      settings.dictationSessionToken = UUID().uuidString
      settings.synchronize()
    }

    // Write request to bridge
    let request = LLMRequest(
      text: inputText,
      action: action,
      customPromptId: customPromptId,
      language: language,
    )
    LLMBridge.writeRequest(request)

    // Signal main app
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.requestLLMProcessing)
  }

  /// Checks for a pending LLM result that may have been written while the extension was suspended.
  func checkForPendingLLMResult() {
    guard let result = LLMBridge.readResult(), !result.isEmpty else { return }
    self.insertLLMResult()
  }

  // MARK: Private

  private static func detectLanguage(from text: String) -> String? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let dominant = recognizer.dominantLanguage else { return nil }
    return dominant.rawValue
  }

  /// Falls back to inserting the original STT text if LLM processing fails
  /// and the text was never inserted into the document (direct auto-action flow).
  private func insertPendingAutoActionFallback() {
    guard let fallbackText = self.pendingAutoActionText else { return }
    textDocumentProxy.insertText(fallbackText)
    self.pendingAutoActionText = nil
  }

  private func insertLLMResult() {
    guard let result = LLMBridge.readResult(), !result.isEmpty else {
      self.insertPendingAutoActionFallback()
      self.keyboardState.isLLMProcessing = false
      self.keyboardState.isProcessing = false
      return
    }

    // Clamp deletion to actual text available before cursor to avoid over-deleting
    let currentBeforeText = textDocumentProxy.documentContextBeforeInput ?? ""
    let deleteCount = min(self.llmOriginalTextLength, currentBeforeText.count)

    // Delete original text backward from cursor
    for _ in 0 ..< deleteCount {
      textDocumentProxy.deleteBackward()
    }

    // Insert processed text
    textDocumentProxy.insertText(result)

    // Append result to LLM text history
    self.keyboardState.llmTextHistory.append(result)
    self.keyboardState.llmHistoryIndex = self.keyboardState.llmTextHistory.count - 1

    // Clean up
    LLMBridge.clearResult()
    LLMBridge.clearRequest()
    self.keyboardState.isLLMProcessing = false
    self.keyboardState.isProcessing = false
    self.pendingAutoActionText = nil
    self.llmOriginalTextLength = 0
  }

  private func navigateLLMHistory(to targetIndex: Int) {
    let currentIndex = self.keyboardState.llmHistoryIndex
    let currentExpected = self.keyboardState.llmTextHistory[currentIndex]

    // Validate that the text in the document matches what we expect
    let beforeText = textDocumentProxy.documentContextBeforeInput ?? ""
    guard beforeText == currentExpected else {
      self.keyboardState.clearLLMHistory()
      return
    }

    let targetText = self.keyboardState.llmTextHistory[targetIndex]

    self.isPerformingHistoryNavigation = true

    // Delete current text
    for _ in 0 ..< beforeText.count {
      textDocumentProxy.deleteBackward()
    }

    // Insert target text
    textDocumentProxy.insertText(targetText)
    self.keyboardState.llmHistoryIndex = targetIndex

    self.isPerformingHistoryNavigation = false
  }
}

// MARK: - LLM History Navigation

extension KeyboardViewController {

  func undoLLM() {
    guard self.keyboardState.canUndoLLM else { return }
    self.navigateLLMHistory(to: self.keyboardState.llmHistoryIndex - 1)
  }

  func redoLLM() {
    guard self.keyboardState.canRedoLLM else { return }
    self.navigateLLMHistory(to: self.keyboardState.llmHistoryIndex + 1)
  }
}
