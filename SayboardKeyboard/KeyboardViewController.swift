
import ObjectiveC

import SwiftUI
import UIKit

final class KeyboardViewController: UIInputViewController {

  static var llmCompleteObserver: DarwinNotificationObserver?
  static var llmFailedObserver: DarwinNotificationObserver?
  static var llmStartedObserver: DarwinNotificationObserver?
  nonisolated(unsafe) static weak var activeInstance: KeyboardViewController?

  var llmOriginalText = ""
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
      let kind = self.keyboardState.keyboardKind
      let initialHeight = KeyboardMetrics.totalHeight(actionBarVisible: false, kind: kind)
      let hc = view.heightAnchor.constraint(equalToConstant: initialHeight)
      hc.priority = UILayoutPriority(rawValue: 999)
      hc.isActive = true
      self.heightConstraint = hc
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.keyboardState.bootstrapLayoutSettings()
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
    self.updateKeyboardHeight(actionBarVisible: false)
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
    let _ = text?.isEmpty ?? true
    guard let text, !text.isEmpty else {
      DiagnosticLog.write("keyboard: NO TEXT available to insert")
      let settings = SharedSettings()
      settings.synchronize()
      if let outcome = settings.lastDictationOutcome {
        self.keyboardState.dictationOutcome = outcome
      }
      return
    }
    self.keyboardState.dictationOutcome = nil
    if !self.isPerformingHistoryNavigation {
      self.keyboardState.clearLLMHistory()
    }
    TranscriptionBridge.clearTranscription()

    if self.autoApplyLLMIfNeeded(directText: text) {
      return
    }

    DiagnosticLog.write("keyboard: inserting \(text.count) chars into textDocumentProxy")
    textDocumentProxy.insertText(text)
    self.copyFinalTextToClipboardIfEnabled(text)
  }

  func copyFinalTextToClipboardIfEnabled(_ text: String) {
    guard SharedSettings().alsoCopyToClipboard else { return }
    UIPasteboard.general.string = text
  }

  func pingMainAppForSessionStatus() {
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.requestSessionStatus)
  }

  private static let staleFallbackTimeout: TimeInterval = 5
  private static let heartbeatStaleThreshold: TimeInterval = 1.5

  private static var transcriptionObserver: DarwinNotificationObserver?
  private static var dictationStartedObserver: DarwinNotificationObserver?
  private static var dictationStoppedObserver: DarwinNotificationObserver?
  private static var sessionStartedObserver: DarwinNotificationObserver?
  private static var sessionEndedObserver: DarwinNotificationObserver?
  private static var modelLoadingFailedObserver: DarwinNotificationObserver?

  private var heightConstraint: NSLayoutConstraint?
  private var hostingHeightConstraint: NSLayoutConstraint?
  private var actionBarVisible = false
  private var statusStripHeight: CGFloat = 0

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
        let _ = vc.keyboardState.isRecording
        let _ = vc.keyboardState.isProcessing
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
    let _ = self.keyboardState.isSessionActive

    guard !processing, !recording else {
      return
    }
    saveHostBundleId()
    let settings = SharedSettings()
    settings.synchronize()

    let heartbeatAge = CFAbsoluteTimeGetCurrent() - settings.mainAppHeartbeat
    if heartbeatAge > Self.heartbeatStaleThreshold {
      self.openDictateDeepLinkFallback(reason: "heartbeat stale (\(heartbeatAge)s)")
      return
    }

    settings.dictationSessionToken = UUID().uuidString
    settings.synchronize()
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.requestStartDictation)

    self.staleFallbackTimer?.invalidate()
    self.staleFallbackTimer = Timer.scheduledTimer(
      withTimeInterval: Self.staleFallbackTimeout,
      repeats: false,
    ) { [weak self] _ in
      DispatchQueue.main.async {
        guard let self else { return }
        let sessionActive = self.keyboardState.isSessionActive
        let isRec = self.keyboardState.isRecording
        self.openDictateDeepLinkFallback(
          reason: "stale fallback fired (no response in \(Self.staleFallbackTimeout)s, session=\(sessionActive) rec=\(isRec))"
        )
      }
    }
  }

  private func openDictateDeepLinkFallback(reason _: String) {
    let settings = SharedSettings()
    settings.isSessionActive = false
    settings.keyboardRequestedDictationAt = CFAbsoluteTimeGetCurrent()
    settings.keyboardRequestedDictation = true
    settings.dictationSessionToken = UUID().uuidString
    settings.synchronize()
    self.keyboardState.isSessionActive = false
    self.keyboardState.isProcessing = false
    guard let url = DeepLink.dictateURL else { return }
    if let openAction = self.keyboardState.openURLAction {
      openAction(url)
    } else {
      self.openURL(url)
    }
  }

}

extension KeyboardViewController {

  func stopDictationViaDarwin() {
    let _ = self.keyboardState.isRecording
    let _ = self.keyboardState.isSessionActive
    self.keyboardState.isProcessing = true
    self.keyboardState.syncModelLoading()
    self.keyboardState.stopLevelPolling()
    let _ = self.keyboardState.isModelLoading
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.requestStopDictation)
    self.startProcessingTimeout()
  }

  private func setupSessionLifecycleObservers() {
    Self.sessionStartedObserver?.stopObserving()
    Self.sessionEndedObserver?.stopObserving()
    Self.sessionStartedObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.sessionStarted
    ) {
      DispatchQueue.main.async {
        guard let vc = Self.activeInstance else { return }
        let _ = vc.keyboardState.isSessionActive
        let isProc = vc.keyboardState.isProcessing
        vc.pingValidator.cancel()
        vc.keyboardState.isSessionActive = true
        if isProc || vc.keyboardState.isLLMProcessing {
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
        let _ = vc.keyboardState.isSessionActive
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

extension KeyboardViewController {

  func updateKeyboardHeight(actionBarVisible: Bool) {
    self.actionBarVisible = actionBarVisible
    self.applyKeyboardHeight()
  }

  func updateStatusStripHeight(_ height: CGFloat) {
    let rounded = height.rounded(.up)
    guard self.statusStripHeight != rounded else { return }
    self.statusStripHeight = rounded
    self.applyKeyboardHeight()
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

    let kind = self.keyboardState.keyboardKind
    let initialHeight = KeyboardMetrics.totalHeight(actionBarVisible: false, kind: kind)
    let hostingHeight = hosting.view.heightAnchor.constraint(equalToConstant: initialHeight)
    NSLayoutConstraint.activate([
      hosting.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      hosting.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      hosting.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
      hostingHeight,
    ])
    self.hostingHeightConstraint = hostingHeight

    self.hostingController = hosting
  }

  private func applyKeyboardHeight() {
    guard let hc = self.heightConstraint else { return }
    let base = KeyboardMetrics.totalHeight(
      actionBarVisible: self.actionBarVisible,
      kind: self.keyboardState.keyboardKind,
    )
    let target = base + self.statusStripHeight
    guard hc.constant != target else { return }
    hc.constant = target
    self.hostingHeightConstraint?.constant = target
    UIView.performWithoutAnimation {
      self.view.layoutIfNeeded()
      self.view.superview?.layoutIfNeeded()
    }
  }

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
      setStatusStripHeight: { [weak self] height in
        self?.updateStatusStripHeight(height)
      },
    )
  }
}
