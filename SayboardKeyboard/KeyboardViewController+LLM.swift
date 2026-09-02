
import NaturalLanguage

import UIKit

extension KeyboardViewController {

  func setupLLMObservers() {
    Self.llmStartedObserver?.stopObserving()
    Self.llmCompleteObserver?.stopObserving()
    Self.llmFailedObserver?.stopObserving()
    Self.llmStartedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.llmProcessingStarted
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else { return }
        vc.keyboardState.isLLMProcessing = true
      }
    }

    Self.llmCompleteObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.llmProcessingComplete
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else { return }
        vc.insertLLMResult()
      }
    }

    Self.llmFailedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.llmProcessingFailed
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else { return }
        vc.insertPendingAutoActionFallback()
        vc.keyboardState.isLLMProcessing = false
        vc.keyboardState.isProcessing = false
      }
    }
  }

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
      inputText = directText
      self.llmOriginalText = ""
      self.pendingAutoActionText = directText
    } else {
      let beforeText = textDocumentProxy.documentContextBeforeInput ?? ""
      let trimmedText = beforeText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedText.isEmpty else {
        self.keyboardState.llmError = .noTextBeforeCursor
        self.updateKeyboardHeight(actionBarVisible: false)
        return
      }
      inputText = beforeText
      self.llmOriginalText = beforeText
      self.pendingAutoActionText = nil
    }

    self.keyboardState.isLLMProcessing = true

    if self.keyboardState.llmTextHistory.isEmpty {
      self.keyboardState.llmTextHistory = [inputText]
      self.keyboardState.llmHistoryIndex = 0
    } else {
      let idx = self.keyboardState.llmHistoryIndex
      self.keyboardState.llmTextHistory = Array(self.keyboardState.llmTextHistory.prefix(idx + 1))
    }

    let language = Self.detectLanguage(from: inputText)

    let settings = SharedSettings()
    if settings.dictationSessionToken == nil {
      settings.dictationSessionToken = UUID().uuidString
      settings.synchronize()
    }

    let request = LLMRequest(
      text: inputText,
      action: action,
      customPromptId: customPromptId,
      language: language,
    )
    LLMBridge.writeRequest(request)

    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.requestLLMProcessing)
    DiagnosticLog.write("llm/kb: requested \(action.rawValue), text=\(inputText.count) chars")
  }

  func checkForPendingLLMResult() {
    guard let result = LLMBridge.readResult(), !result.isEmpty else { return }
    self.insertLLMResult()
  }

  private static func detectLanguage(from text: String) -> String? {
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    guard let dominant = recognizer.dominantLanguage else { return nil }
    return dominant.rawValue
  }

  private func insertPendingAutoActionFallback() {
    guard let fallbackText = self.pendingAutoActionText else { return }
    textDocumentProxy.insertText(fallbackText)
    self.copyFinalTextToClipboardIfEnabled(fallbackText)
    self.pendingAutoActionText = nil
  }

  private func insertLLMResult() {
    guard let result = LLMBridge.readResult(), !result.isEmpty else {
      DiagnosticLog.write("llm/kb: notified complete but bridge held no result")
      self.insertPendingAutoActionFallback()
      self.keyboardState.isLLMProcessing = false
      self.keyboardState.isProcessing = false
      return
    }
    DiagnosticLog.write("llm/kb: inserting \(result.count) chars")

    let currentBeforeText = textDocumentProxy.documentContextBeforeInput ?? ""
    let expected = self.llmOriginalText
    guard expected.isEmpty || currentBeforeText == expected else {
      DiagnosticLog.write("llm/kb: document changed under the request, refusing to replace")
      self.keyboardState.llmError = .noTextBeforeCursor
      self.finishLLMInsertion()
      return
    }

    for _ in 0 ..< expected.count {
      textDocumentProxy.deleteBackward()
    }

    textDocumentProxy.insertText(result)
    self.copyFinalTextToClipboardIfEnabled(result)

    self.keyboardState.llmTextHistory.append(result)
    self.keyboardState.llmHistoryIndex = self.keyboardState.llmTextHistory.count - 1

    self.finishLLMInsertion()
  }

  private func finishLLMInsertion() {
    LLMBridge.clearResult()
    LLMBridge.clearRequest()
    self.keyboardState.isLLMProcessing = false
    self.keyboardState.isProcessing = false
    self.pendingAutoActionText = nil
    self.llmOriginalText = ""
  }

  private func navigateLLMHistory(to targetIndex: Int) {
    let currentIndex = self.keyboardState.llmHistoryIndex
    let currentExpected = self.keyboardState.llmTextHistory[currentIndex]

    let beforeText = textDocumentProxy.documentContextBeforeInput ?? ""
    guard beforeText == currentExpected else {
      self.keyboardState.clearLLMHistory()
      return
    }

    let targetText = self.keyboardState.llmTextHistory[targetIndex]

    self.isPerformingHistoryNavigation = true

    for _ in 0 ..< beforeText.count {
      textDocumentProxy.deleteBackward()
    }

    textDocumentProxy.insertText(targetText)
    self.copyFinalTextToClipboardIfEnabled(targetText)
    self.keyboardState.llmHistoryIndex = targetIndex

    self.isPerformingHistoryNavigation = false
  }
}

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
