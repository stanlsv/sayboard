import Foundation

import QuartzCore
import SwiftUI

@MainActor
final class KeyboardState: ObservableObject {

  @Published var isRecording = false
  @Published var isProcessing = false
  @Published var isSessionActive = false
  @Published var isModelLoading = false
  @Published var hasPreparedModelOnce = false
  @Published var hasUsableModel = false
  @Published var parakeetV3NeedsRedownload = false
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
  @Published var dictationOutcome: DictationOutcome?
  @Published var needsInputModeSwitchKey = false
  @Published var showGlobeKey = true
  @Published var keyboardHapticsEnabled = true
  @Published var keyboardKind = KeyboardKind.standard

  var onStaleLevelDetected: (() -> Void)?

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

  func bootstrapLayoutSettings() {
    self.settings.synchronize()
    self.keyboardKind = self.settings.keyboardKind
    self.keyboardHapticsEnabled = self.settings.keyboardHapticsEnabled
  }

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
    self.hasPreparedModelOnce = self.settings.hasPreparedModelOnce
    self.hasUsableModel = self.settings.hasUsableModel
    self.parakeetV3NeedsRedownload = self.settings.parakeetV3NeedsRedownload
    self.isMicrophoneAuthorized = self.settings.isMicrophoneAuthorized
    self.useCustomSpaceBar = self.settings.useCustomSpaceBar
    self.keyboardKind = self.settings.keyboardKind
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
    self.showGlobeKey = self.settings.showGlobeKey
    self.keyboardHapticsEnabled = self.settings.keyboardHapticsEnabled
    self.checkDiskSpace()
    let _ = self.displayLink != nil
  }

  func syncModelLoading() {
    self.settings.synchronize()
    self.isModelLoading = self.settings.isModelLoading
    self.hasPreparedModelOnce = self.settings.hasPreparedModelOnce
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
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 20, preferred: 20)
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

  private static let staleLevelThreshold: TimeInterval = 2

  private let settings = SharedSettings()
  private let levelBridge = AudioLevelBridge(mode: .reader)
  private var displayLink: CADisplayLink?
  private var displayLinkTarget: DisplayLinkTarget?
  private var lastLevelChangeTime: CFTimeInterval = 0
  private var lastPolledLevel: Float = 0
  private var pollCount = 0
  private var staleLevelDetected = false

  private func checkDiskSpace() {
    self.isLowDiskSpace = DiskSpace.isLow()
  }

  private func pollAudioLevel() {
    let newLevel = self.levelBridge.readLevel()
    let now = CACurrentMediaTime()

    if newLevel != self.lastPolledLevel {
      self.lastPolledLevel = newLevel
      self.lastLevelChangeTime = now
    }

    if newLevel != self.audioLevel {
      withAnimation(.interpolatingSpring(duration: 0.08, bounce: 0)) {
        self.audioLevel = newLevel
      }
    }

    self.pollCount += 1
    if self.pollCount % 20 == 0 { }

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

private final class DisplayLinkTarget: NSObject {

  init(callback: @escaping () -> Bool) {
    self.callback = callback
  }

  weak var link: CADisplayLink?

  @objc
  func tick() {
    if !self.callback() {
      self.link?.invalidate()
    }
  }

  private let callback: () -> Bool
}
