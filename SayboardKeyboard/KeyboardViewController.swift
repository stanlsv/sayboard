import ObjectiveC

import SwiftUI
import UIKit

// MARK: - KeyboardViewController

final class KeyboardViewController: UIInputViewController {

  // MARK: Internal

  static var llmCompleteObserver: DarwinNotificationObserver?
  static var llmFailedObserver: DarwinNotificationObserver?
  static var llmStartedObserver: DarwinNotificationObserver?
  /// Static observers: one set per process, dispatching to activeInstance.
  /// Prevents observer leaks when iOS creates multiple VC instances in the same process.
  nonisolated(unsafe) static weak var activeInstance: KeyboardViewController?

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
      let hc = view.heightAnchor.constraint(equalToConstant: KeyboardMetrics.height)
      hc.priority = UILayoutPriority(rawValue: 999)
      hc.isActive = true
      self.heightConstraint = hc
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    Self.activeInstance = self
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
    Self.activeInstance = self
    if self.hostingController == nil {
      self.setupKeyboardView()
    }
    self.keyboardState.refresh()
    self.keyboardState.needsInputModeSwitchKey = self.needsInputModeSwitchKey
    SharedSettings().needsInputModeSwitchKey = self.needsInputModeSwitchKey
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

  private static let staleFallbackTimeout: TimeInterval = 5

  private static var transcriptionObserver: DarwinNotificationObserver?
  private static var dictationStartedObserver: DarwinNotificationObserver?
  private static var dictationStoppedObserver: DarwinNotificationObserver?
  private static var sessionStartedObserver: DarwinNotificationObserver?
  private static var sessionEndedObserver: DarwinNotificationObserver?
  private static var modelLoadingFailedObserver: DarwinNotificationObserver?

  private var heightConstraint: NSLayoutConstraint?
  private var hostingHeightConstraint: NSLayoutConstraint?

  private var hostingController: UIHostingController<KeyboardView>?
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
    Self.transcriptionObserver?.stopObserving()
    Self.transcriptionObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.transcriptionReady
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else {
          return
        }
        let isRec = vc.keyboardState.isRecording
        let isProc = vc.keyboardState.isProcessing
        vc.cancelProcessingTimeout()
        vc.insertTranscribedText()
        vc.finalizeProcessingPipeline()
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
    Self.dictationStartedObserver?.stopObserving()
    Self.dictationStoppedObserver?.stopObserving()
    Self.dictationStartedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.dictationStarted
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else {
          return
        }
        vc.staleFallbackTimer?.invalidate()
        vc.staleFallbackTimer = nil
        vc.pingValidator.cancel()
        vc.cancelProcessingTimeout()
        vc.keyboardState.isProcessing = false
        vc.keyboardState.isRecording = true
        if !vc.isPerformingHistoryNavigation {
          vc.keyboardState.clearLLMHistory()
        }
        // Dictation implies an active session for the Darwin mic-button path
        vc.keyboardState.isSessionActive = true
        vc.keyboardState.startLevelPolling()
      }
    }

    Self.dictationStoppedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.dictationStopped
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else {
          return
        }
        vc.cancelProcessingTimeout()
        vc.keyboardState.stopLevelPolling()
        vc.keyboardState.isRecording = false
        vc.keyboardState.syncModelLoading()
        // transcriptionReady may not have arrived yet due to cross-process ordering
        vc.insertTranscribedText()
        vc.finalizeProcessingPipeline()
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
    Self.sessionStartedObserver?.stopObserving()
    Self.sessionEndedObserver?.stopObserving()
    Self.sessionStartedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.sessionStarted
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else { return }
        let wasActive = vc.keyboardState.isSessionActive
        let isProc = vc.keyboardState.isProcessing
        vc.pingValidator.cancel()
        vc.keyboardState.isSessionActive = true
        if isProc || vc.keyboardState.isLLMProcessing {
          // App is alive — note the ping response but let processing timeout continue
          vc.receivedPingDuringProcessing = true
        } else {
          vc.cancelProcessingTimeout()
        }
      }
    }

    Self.sessionEndedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.sessionEnded
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else { return }
        let wasActive = vc.keyboardState.isSessionActive
        vc.cancelProcessingTimeout()
        vc.keyboardState.stopLevelPolling()
        vc.keyboardState.isSessionActive = false
        vc.keyboardState.isRecording = false
        vc.keyboardState.isProcessing = false
      }
    }
  }

  private func setupModelLoadingObservers() {
    Self.modelLoadingFailedObserver?.stopObserving()
    Self.modelLoadingFailedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.modelLoadingFailed
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else { return }
        vc.resetProcessingState()
      }
    }
  }
}

// MARK: - Dynamic Keyboard Height

extension KeyboardViewController {

  // MARK: Internal

  func updateKeyboardHeight(actionBarVisible: Bool) {
    guard let hc = self.heightConstraint else { return }
    let target = KeyboardMetrics.totalHeight(actionBarVisible: actionBarVisible)
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

    let hostingHeight = hosting.view.heightAnchor.constraint(equalToConstant: KeyboardMetrics.height)
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
