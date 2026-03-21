import Foundation

import QuartzCore

// MARK: - KeyboardState

// KeyboardState -- Observable state synced from shared UserDefaults

@MainActor
final class KeyboardState: ObservableObject {

  // MARK: Internal

  @Published var isRecording = false
  @Published var isProcessing = false
  @Published var isSessionActive = false
  @Published var isModelLoading = false
  @Published var hasUsableModel = false
  @Published var isMicrophoneAuthorized = false
  @Published var hasFullAccess = false
  @Published var useCustomSpaceBar = false
  @Published var isTranslationMode = false
  @Published var selectedVariantSupportsTranslation = false
  @Published var audioLevel: Float = 0
  @Published var isLowDiskSpace = false
  @Published var hasUsableLLMModel = false
  @Published var isLLMProcessing = false
  @Published var llmEnabled = false
  @Published var llmCustomPrompts = [LLMCustomPrompt]()
  @Published var defaultLLMActionSelection = LLMActionSelection.none
  @Published var longPressLLMAction = LLMActionSelection.none
  @Published var disabledLLMActions = Set<LLMAction>()
  @Published var llmTextHistory = [String]()
  @Published var llmHistoryIndex = -1
  @Published var showLLMActions = false
  @Published var llmError: LLMError?

  /// Called when audio level has been stale (unchanged) for too long during recording.
  /// Indicates the main app was likely killed.
  var onStaleLevelDetected: (() -> Void)?

  /// Bridged from SwiftUI `@Environment(\.openURL)` — works on iOS 18
  /// where the UIResponder chain `openURL:` is broken.
  var openURLAction: ((URL) -> Void)?

  var canUndoLLM: Bool {
    self.llmHistoryIndex > 0
  }

  var canRedoLLM: Bool {
    self.llmHistoryIndex >= 0 && self.llmHistoryIndex < self.llmTextHistory.count - 1
  }

  var hasLLMHistory: Bool {
    self.llmTextHistory.count > 1
  }

  func clearLLMHistory() {
    self.llmTextHistory = []
    self.llmHistoryIndex = -1
  }

  /// Reloads state from shared UserDefaults.
  /// Session/recording state is read from SharedSettings (last known value
  /// written by the main app) and then validated via a Darwin ping
  /// (`requestSessionStatus`) — the main app responds with
  /// `sessionStarted`/`dictationStarted` if it is still alive.
  /// If the main app was killed, the ping gets no response and the stale
  /// audio level detector will reset the state.
  func refresh() {
    self.settings.synchronize()
    let prevRec = self.isRecording
    let prevSession = self.isSessionActive
    self.isRecording = self.settings.isRecording
    self.isSessionActive = self.settings.isSessionActive
    if self.isRecording, !self.isSessionActive {
      self.isRecording = false
      self.settings.isRecording = false
    }
    self.isProcessing = false
    self.isModelLoading = self.settings.isModelLoading
    self.hasUsableModel = self.settings.hasUsableModel
    self.isMicrophoneAuthorized = self.settings.isMicrophoneAuthorized
    self.useCustomSpaceBar = self.settings.useCustomSpaceBar
    let selectedVariant = self.settings.selectedVariant
    self.selectedVariantSupportsTranslation = selectedVariant.supportsTranslation
    if !selectedVariant.supportsTranslation {
      self.isTranslationMode = false
      self.settings.isTranslationMode = false
    }
    if self.isRecording != prevRec || self.isSessionActive != prevSession { }
    self.hasUsableLLMModel = self.settings.hasUsableLLMModel
    self.isLLMProcessing = self.settings.isLLMProcessing
    self.llmEnabled = self.settings.llmEnabled
    self.llmCustomPrompts = self.settings.llmCustomPrompts
    self.defaultLLMActionSelection = self.settings.defaultLLMActionSelection
    self.longPressLLMAction = self.settings.longPressLLMAction
    self.disabledLLMActions = self.settings.disabledLLMActions
    self.checkDiskSpace()
    let polling = self.displayLink != nil
  }

  /// Re-reads only isModelLoading from SharedSettings.
  /// Used by dictationStopped to preserve loading state if the model is still loading.
  func syncModelLoading() {
    self.settings.synchronize()
    self.isModelLoading = self.settings.isModelLoading
  }

  func toggleTranslationMode() {
    self.isTranslationMode.toggle()
    self.settings.isTranslationMode = self.isTranslationMode
  }

  func startLevelPolling() {
    guard self.displayLink == nil else { return }
    self.lastPolledLevel = 0
    self.lastLevelChangeTime = CACurrentMediaTime()
    self.staleLevelDetected = false
    let target = DisplayLinkTarget { [weak self] in
      guard let self else { return false }
      self.pollAudioLevel()
      return true
    }
    let link = CADisplayLink(target: target, selector: #selector(DisplayLinkTarget.tick))
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
    link.add(to: .main, forMode: .common)
    target.link = link
    self.displayLinkTarget = target
    self.displayLink = link
  }

  func stopLevelPolling() {
    self.displayLink?.invalidate()
    self.displayLink = nil
    self.displayLinkTarget = nil
    self.audioLevel = 0
  }

  // MARK: Private

  private static let staleLevelThreshold: TimeInterval = 2
  private static let lowDiskSpaceThreshold: Int64 = 1_000_000_000

  private let settings = SharedSettings()
  private let levelBridge = AudioLevelBridge(mode: .reader)
  private var displayLink: CADisplayLink?
  private var displayLinkTarget: DisplayLinkTarget?
  private var lastLevelChangeTime: CFTimeInterval = 0
  private var lastPolledLevel: Float = 0
  private var pollCount = 0
  private var staleLevelDetected = false

  private func checkDiskSpace() {
    do {
      let homeURL = URL(fileURLWithPath: NSHomeDirectory())
      let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
      if let available = values.volumeAvailableCapacityForImportantUsage {
        self.isLowDiskSpace = available < Self.lowDiskSpaceThreshold
      }
    } catch {
      // no-op
    }
  }

  private func pollAudioLevel() {
    let newLevel = self.levelBridge.readLevel()
    let now = CACurrentMediaTime()

    if newLevel != self.lastPolledLevel {
      self.lastPolledLevel = newLevel
      self.lastLevelChangeTime = now
    }

    if newLevel != self.audioLevel {
      self.audioLevel = newLevel
    }

    // Diagnostic: log level once per second (every 30 polls at 30Hz)
    self.pollCount += 1
    if self.pollCount % 30 == 0 { }

    // If level hasn't changed during recording, app may be dead.
    // staleLevelDetected ensures this fires at most once per polling session.
    if
      !self.staleLevelDetected,
      self.isRecording,
      self.lastLevelChangeTime > 0,
      now - self.lastLevelChangeTime >= Self.staleLevelThreshold
    {
      self.staleLevelDetected = true
      self.stopLevelPolling()
      self.onStaleLevelDetected?()
    }
  }
}

// MARK: - DisplayLinkTarget

/// CADisplayLink retains its target and requires an @objc selector.
/// This wrapper avoids forcing NSObject conformance on KeyboardState.
/// The callback returns `true` to keep running, `false` to self-invalidate.
/// When KeyboardState is deallocated, [weak self] becomes nil → returns false
/// → the display link invalidates itself (no zombie display links).
private final class DisplayLinkTarget: NSObject {

  // MARK: Lifecycle

  init(callback: @escaping () -> Bool) {
    self.callback = callback
  }

  // MARK: Internal

  /// Set after creating the CADisplayLink so the target can self-invalidate.
  weak var link: CADisplayLink?

  @objc
  func tick() {
    if !self.callback() {
      self.link?.invalidate()
    }
  }

  // MARK: Private

  private let callback: () -> Bool
}
