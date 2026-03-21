import ObjectiveC

import SwiftUI
import UIKit

// MARK: - KeyboardViewController

final class KeyboardViewController: UIInputViewController {

  // MARK: Internal

  var llmCompleteObserver: DarwinNotificationObserver?
  var llmFailedObserver: DarwinNotificationObserver?
  var llmStartedObserver: DarwinNotificationObserver?
  var llmOriginalTextLength = 0
  var isPerformingHistoryNavigation = false
  var pendingAutoActionText: String?

  let keyboardState = KeyboardState()

  var processingTimeoutTimer: Timer?
  var processingStartTime: Date?
  var receivedPingDuringProcessing = false

  override func loadView() {
    super.loadView()
    view.backgroundColor = .clear
    view.clipsToBounds = true

    if let inputView = view as? UIInputView {
      inputView.allowsSelfSizing = true
    }
  }

  override func updateViewConstraints() {
    super.updateViewConstraints()
    if self.heightConstraint == nil {
      for constraint in view.constraintsAffectingLayout(for: .vertical) {
        constraint.priority = .defaultHigh
      }
      let hc = view.heightAnchor.constraint(equalToConstant: Self.keyboardHeight)
      hc.priority = UILayoutPriority(rawValue: 999)
      hc.isActive = true
      self.heightConstraint = hc
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.setupTranscriptionObserver()
    self.setupSessionObservers()
    self.setupForegroundObserver()
    self.setupLLMObservers()
    self.keyboardState.onStaleLevelDetected = { [weak self] in
      guard let self else { return }
      self.resetProcessingState()
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if self.hostingController == nil {
      self.setupKeyboardView()
    }
    self.keyboardState.refresh()
    self.keyboardState.isTranslationMode = SharedSettings().isTranslationMode
    self.syncFullAccessIfChanged()
    self.pingMainAppForSessionStatus()
    self.pingValidator.startIfNeeded(for: self.keyboardState)
    saveHostBundleId()
    self.insertTranscribedText()
    self.checkForPendingLLMResult()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if !self.keyboardState.isRecording, !self.keyboardState.isProcessing {
      self.keyboardState.stopLevelPolling()
    }
  }

  func insertTranscribedText() {
    let text = TranscriptionBridge.readTranscription()
    let isEmpty = text?.isEmpty ?? true
    guard let text, !text.isEmpty else {
      return
    }
    if !self.isPerformingHistoryNavigation {
      self.keyboardState.clearLLMHistory()
    }
    TranscriptionBridge.clearTranscription()

    // If auto-action is configured, skip displaying STT text and pass directly to LLM
    if self.autoApplyLLMIfNeeded(directText: text) {
      return
    }

    textDocumentProxy.insertText(text)
  }

  /// Pings the main app; it responds with `sessionStarted`/`dictationStarted` if alive.
  func pingMainAppForSessionStatus() {
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.requestSessionStatus)
  }

  // MARK: Private

  /// Base keyboard height: 14.5 (top) + 168 (micRow) + 8.5 (spacing) + 49 (bottom) = 240
  private static let keyboardHeight: CGFloat = 240
  /// Extra height added when the LLM action bar is visible (top 8 + chip 34)
  private static let actionBarExtraHeight: CGFloat = 42
  private static let staleFallbackTimeout: TimeInterval = 5

  private var heightConstraint: NSLayoutConstraint?
  private var hostingHeightConstraint: NSLayoutConstraint?

  private var hostingController: UIHostingController<KeyboardView>?
  private var transcriptionObserver: DarwinNotificationObserver?
  private var dictationStartedObserver: DarwinNotificationObserver?
  private var dictationStoppedObserver: DarwinNotificationObserver?
  private var sessionStartedObserver: DarwinNotificationObserver?
  private var sessionEndedObserver: DarwinNotificationObserver?
  private var modelLoadingFailedObserver: DarwinNotificationObserver?
  private var staleFallbackTimer: Timer?
  private var lastSyncedFullAccess = false
  private var hasPerformedInitialFullAccessSync = false
  private let pingValidator = PingValidator()

  private func syncFullAccessIfChanged() {
    let current = self.hasFullAccess
    self.keyboardState.hasFullAccess = current
    guard !self.hasPerformedInitialFullAccessSync || current != self.lastSyncedFullAccess else { return }
    self.hasPerformedInitialFullAccessSync = true
    self.lastSyncedFullAccess = current
    let settings = SharedSettings()
    settings.hasFullAccess = current
    settings.synchronize()
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.fullAccessChanged)
  }

  private func setupTranscriptionObserver() {
    self.transcriptionObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.transcriptionReady
    ) { [weak self] in
      DispatchQueue.main.async {
        guard let self else {
          return
        }
        let isRec = self.keyboardState.isRecording
        let isProc = self.keyboardState.isProcessing
        self.cancelProcessingTimeout()
        self.insertTranscribedText()
        self.finalizeProcessingPipeline()
      }
    }
  }

  private func setupForegroundObserver() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.hostDidEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil,
    )
  }

  @objc
  private func hostDidEnterForeground() {
    self.syncFullAccessIfChanged()
    self.keyboardState.refresh()
    self.pingMainAppForSessionStatus()
    self.pingValidator.startIfNeeded(for: self.keyboardState)
    self.insertTranscribedText()
    self.checkForPendingLLMResult()
  }

  private func setupSessionObservers() {
    self.dictationStartedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.dictationStarted
    ) { [weak self] in
      DispatchQueue.main.async {
        guard let self else {
          return
        }
        self.staleFallbackTimer?.invalidate()
        self.staleFallbackTimer = nil
        self.pingValidator.cancel()
        self.cancelProcessingTimeout()
        self.keyboardState.isProcessing = false
        self.keyboardState.isRecording = true
        if !self.isPerformingHistoryNavigation {
          self.keyboardState.clearLLMHistory()
        }
        // Dictation implies an active session for the Darwin mic-button path
        self.keyboardState.isSessionActive = true
        self.keyboardState.startLevelPolling()
      }
    }

    self.dictationStoppedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.dictationStopped
    ) { [weak self] in
      DispatchQueue.main.async {
        guard let self else {
          return
        }
        self.cancelProcessingTimeout()
        self.keyboardState.stopLevelPolling()
        self.keyboardState.isRecording = false
        self.keyboardState.syncModelLoading()
        // transcriptionReady may not have arrived yet due to cross-process ordering
        self.insertTranscribedText()
        self.finalizeProcessingPipeline()
      }
    }

    self.setupSessionLifecycleObservers()
    self.setupModelLoadingObservers()
  }

  private func finalizeProcessingPipeline() {
    self.keyboardState.isProcessing = false
    if self.keyboardState.isLLMProcessing {
      self.startProcessingTimeout()
    }
  }

  private func deleteAllText() {
    while textDocumentProxy.hasText {
      textDocumentProxy.deleteBackward()
    }
    if !self.isPerformingHistoryNavigation {
      self.keyboardState.clearLLMHistory()
    }
  }

  private func startDictationViaDarwin() {
    let processing = self.keyboardState.isProcessing
    let recording = self.keyboardState.isRecording
    let sessionActive = self.keyboardState.isSessionActive

    guard !processing, !recording else {
      return
    }
    // Re-detect host bundle ID right before dictation.
    // The ivar may not be populated during viewWillAppear but is available by user interaction.
    saveHostBundleId()
    let settings = SharedSettings()
    settings.keyboardRequestedDictation = true
    settings.dictationSessionToken = UUID().uuidString
    settings.synchronize()
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.requestStartDictation)

    // Stale session fallback: if no dictationStarted within timeout,
    // the app may have been killed. Reset session and auto-open via deep link.
    self.staleFallbackTimer?.invalidate()
    self.staleFallbackTimer = Timer.scheduledTimer(
      withTimeInterval: Self.staleFallbackTimeout,
      repeats: false,
    ) { [weak self] _ in
      DispatchQueue.main.async {
        let sessionActive = self?.keyboardState.isSessionActive ?? false
        let isRec = self?.keyboardState.isRecording ?? false
        self?.keyboardState.isSessionActive = false
        self?.keyboardState.isProcessing = false
        if let url = DeepLink.dictateURL {
          let fallbackSettings = SharedSettings()
          fallbackSettings.keyboardRequestedDictation = true
          fallbackSettings.dictationSessionToken = UUID().uuidString
          fallbackSettings.synchronize()
          if let openAction = self?.keyboardState.openURLAction {
            openAction(url)
          } else {
            self?.openURL(url)
          }
        }
      }
    }
  }

}

// MARK: - Session & Model Loading Observers

extension KeyboardViewController {

  // MARK: Internal

  func stopDictationViaDarwin() {
    let recording = self.keyboardState.isRecording
    let sessionActive = self.keyboardState.isSessionActive
    self.keyboardState.isProcessing = true
    self.keyboardState.syncModelLoading()
    self.keyboardState.stopLevelPolling()
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.requestStopDictation)
    self.startProcessingTimeout()
  }

  // MARK: Private

  private func setupSessionLifecycleObservers() {
    self.sessionStartedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.sessionStarted
    ) { [weak self] in
      DispatchQueue.main.async {
        guard let self else { return }
        let wasActive = self.keyboardState.isSessionActive
        let isProc = self.keyboardState.isProcessing
        self.pingValidator.cancel()
        self.keyboardState.isSessionActive = true
        if isProc || self.keyboardState.isLLMProcessing {
          // App is alive — note the ping response but let processing timeout continue
          self.receivedPingDuringProcessing = true
        } else {
          self.cancelProcessingTimeout()
        }
      }
    }

    self.sessionEndedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.sessionEnded
    ) { [weak self] in
      DispatchQueue.main.async {
        let wasActive = self?.keyboardState.isSessionActive ?? false
        self?.cancelProcessingTimeout()
        self?.keyboardState.stopLevelPolling()
        self?.keyboardState.isSessionActive = false
        self?.keyboardState.isRecording = false
        self?.keyboardState.isProcessing = false
      }
    }
  }

  private func setupModelLoadingObservers() {
    self.modelLoadingFailedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.modelLoadingFailed
    ) { [weak self] in
      DispatchQueue.main.async {
        self?.resetProcessingState()
      }
    }
  }
}

// MARK: - Dynamic Keyboard Height

extension KeyboardViewController {

  // MARK: Internal

  func updateKeyboardHeight(actionBarVisible: Bool) {
    guard let hc = self.heightConstraint else { return }
    let target = actionBarVisible
      ? Self.keyboardHeight + Self.actionBarExtraHeight
      : Self.keyboardHeight
    guard hc.constant != target else { return }
    hc.constant = target
    self.hostingHeightConstraint?.constant = target
    UIView.performWithoutAnimation {
      self.view.layoutIfNeeded()
      self.view.superview?.layoutIfNeeded()
    }
  }

  func setupKeyboardView() {
    let proxy = self.makeKeyboardProxy()
    let keyboardView = KeyboardView(proxy: proxy, keyboardState: self.keyboardState)
    let hosting = UIHostingController(rootView: keyboardView)
    hosting.safeAreaRegions = []
    hosting.view.backgroundColor = .clear
    hosting.view.translatesAutoresizingMaskIntoConstraints = false

    self.addChild(hosting)
    self.view.addSubview(hosting.view)
    hosting.didMove(toParent: self)

    let hostingHeight = hosting.view.heightAnchor.constraint(equalToConstant: Self.keyboardHeight)
    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
      hostingHeight,
    ])
    self.hostingHeightConstraint = hostingHeight

    self.hostingController = hosting
  }

  // MARK: Private

  private func makeKeyboardProxy() -> KeyboardProxy {
    KeyboardProxy(
      insertText: { [weak self] text in
        self?.textDocumentProxy.insertText(text)
      },
      deleteBackward: { [weak self] in
        self?.textDocumentProxy.deleteBackward()
      },
      deleteAll: { [weak self] in
        self?.deleteAllText()
      },
      advanceToNextInputMode: { [weak self] in
        self?.advanceToNextInputMode()
      },
      openURL: { [weak self] url in
        self?.openURL(url)
      },
      startDictation: { [weak self] in
        self?.startDictationViaDarwin()
      },
      stopDictation: { [weak self] in
        self?.stopDictationViaDarwin()
      },
      requestLLMProcessing: { [weak self] action, customPromptId in
        self?.requestLLMProcessing(action: action, customPromptId: customPromptId)
      },
      adjustTextPosition: { [weak self] offset in
        self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
      },
      undoLLM: { [weak self] in self?.undoLLM() },
      redoLLM: { [weak self] in self?.redoLLM() },
      setActionBarVisible: { [weak self] visible in
        self?.updateKeyboardHeight(actionBarVisible: visible)
      },
    )
  }
}
