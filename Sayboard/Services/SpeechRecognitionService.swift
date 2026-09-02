import AVFoundation
import Combine
import FluidAudio

import SwiftUI

@MainActor
protocol ModelLoading: AnyObject {
  func loadModel(variant: ModelVariant, from url: URL) async -> Bool
}

@MainActor
final class SpeechRecognitionService: ObservableObject {

  init() {
    self.setupDarwinObservers()
    self.setupSessionCallbacks()
    self.forwardSessionState()
  }

  static let maxRecordingDuration: TimeInterval = 30 * 60

  @Published var isRecording = false
  @Published var isSessionActive = false
  @Published var historySaveGeneration = 0

  let session = BackgroundAudioSession()
  let whisperService = WhisperKitTranscriptionService()
  let parakeetService = ParakeetTranscriptionService()
  let moonshineService = MoonshineTranscriptionService()
  weak var downloadService: ModelDownloadService?

  let settings = SharedSettings()
  let accumulator = AudioBufferAccumulator()
  let audioRecorder = AudioRecorder()
  var currentTranscription = ""
  var currentAudioFileName: String?
  var currentWordBoundaries: (start: Float, end: Float)?

  private(set) var isStopping = false

  var activeLoadState: ModelLoadState {
    switch self.settings.selectedVariant.engine {
    case .whisperKit: self.whisperService.loadState
    case .parakeet: self.parakeetService.loadState
    case .moonshine: self.moonshineService.loadState
    }
  }

  func startRecording() {
    let _ = String(describing: self.activeLoadState)
    let micAuth = self.settings.isMicrophoneAuthorized
    let _ = self.session.isSessionActive
    let _ = self.session.audioEngine.isRunning

    guard !self.isRecording, !self.isStopping else {
      return
    }
    guard micAuth else {
      self.errorMessage = "Microphone access is required for voice input."
      return
    }
    guard self.activeLoadState == .loaded else {
      return
    }

    self.errorMessage = nil
    self.currentTranscription = ""
    self.currentAudioFileName = "\(UUID().uuidString).caf"

    guard self.ensureSessionActive() else {
      return
    }

    self.accumulator.reset()
    self.startAudioCapture()
    self.isRecording = true
    self.settings.isRecording = true
    self.armMaxDurationTimer()
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.dictationStarted)
  }

  func startCapture() {
    let micAuth = self.settings.isMicrophoneAuthorized
    let _ = self.session.isSessionActive
    let _ = self.session.audioEngine.isRunning
    let _ = String(describing: self.activeLoadState)

    guard !self.isRecording, !self.isStopping else {
      return
    }
    guard micAuth else {
      self.errorMessage = "Microphone access is required for voice input."
      return
    }

    self.errorMessage = nil
    self.currentTranscription = ""
    self.currentAudioFileName = "\(UUID().uuidString).caf"

    guard self.ensureSessionActive() else {
      return
    }

    self.accumulator.reset()
    self.startAudioCapture()

    self.isRecording = true
    self.settings.isRecording = true
    self.armMaxDurationTimer()
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.dictationStarted)
  }

  func stopRecording() async {
    let _ = String(describing: self.activeLoadState)

    guard !self.isStopping else {
      return
    }
    guard self.isRecording else {
      self.settings.isRecording = false
      TranscriptionBridge.postDarwinNotification(DarwinNotificationName.dictationStopped)
      return
    }
    self.isRecording = false
    self.isStopping = true

    self.cancelMaxDurationTimer()
    self.session.deactivateTap()
    let savedSamples = self.accumulator.samples

    if self.activeLoadState != .loaded {
      let _ = String(describing: self.activeLoadState)
      if self.activeLoadState == .loading {
        await self.awaitModelLoad()
      } else if let downloadService {
        downloadService.verifyExistingModels()
        await self.loadModelIfAvailable(downloadService: downloadService)
      }
    }

    await self.runFinalTranscription(samples: savedSamples)

    self.saveHistoryRecord()

    self.isStopping = false
    self.settings.isRecording = false
    self.settings.dictationSessionToken = nil
    self.settings.synchronize()
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.dictationStopped)
  }

  func loadModelIfAvailable(downloadService: ModelDownloadService) async {
    let selected = self.settings.selectedVariant
    guard let url = downloadService.activeModelFolderURL else { return }
    _ = await self.loadModel(variant: selected, from: url)
  }

  func reloadModel(variant: ModelVariant, folderURL: URL?) async {
    await self.unloadAllEngines()
    guard let folderURL else { return }
    _ = await self.loadModel(variant: variant, from: folderURL)
  }

  func unloadForLLMProcessing() async {
    if self.isRecording {
      await self.stopRecording()
    }
    await self.unloadAllEngines()
  }

  func deactivateCompletely() async {
    await self.unloadAllEngines()
    self.session.endSession()
  }

  func startRecordingAfterModelLoad() async {
    let _ = String(describing: self.activeLoadState)
    guard !self.isStopping else {
      return
    }
    if self.activeLoadState == .loaded {
      self.startRecording()
    } else {
      self.startCapture()
      if let downloadService {
        self.settings.isModelLoading = true
        Task {
          defer { self.settings.isModelLoading = false }
          downloadService.verifyExistingModels()
          await self.loadModelIfAvailable(downloadService: downloadService)
        }
      }
    }
  }

  private var errorMessage: String?
  private var sessionCancellable: AnyCancellable?

  private var requestStartObserver: DarwinNotificationObserver?
  private var requestStopObserver: DarwinNotificationObserver?
  private var sessionStatusObserver: DarwinNotificationObserver?

  private var maxDurationTimer: Timer?

  private func armMaxDurationTimer() {
    self.maxDurationTimer?.invalidate()
    let cap = Self.maxRecordingDuration
    self.maxDurationTimer = Timer.scheduledTimer(
      withTimeInterval: cap,
      repeats: false,
    ) { [weak self] _ in
      Task { @MainActor [weak self] in await self?.stopRecording() }
    }
  }

  private func cancelMaxDurationTimer() {
    self.maxDurationTimer?.invalidate()
    self.maxDurationTimer = nil
  }

  private func awaitModelLoad() async {
    switch self.settings.selectedVariant.engine {
    case .whisperKit:
      await self.whisperService.waitForLoad()
    case .parakeet:
      await self.parakeetService.waitForLoad()
    case .moonshine:
      await self.moonshineService.waitForLoad()
    }
  }

  private func parakeetModelVersion(for variant: ModelVariant) -> AsrModelVersion {
    switch variant {
    case .parakeetV2: .v2
    case .parakeetV3: .v3
    default: .v3
    }
  }

  private func unloadAllEngines() async {
    await self.whisperService.unloadModel()
    await self.parakeetService.unloadModel()
    self.moonshineService.unloadModel()
  }

  private func ensureSessionActive() -> Bool {
    guard !self.session.isSessionActive else {
      return true
    }
    do {
      try self.session.startSession()
      return true
    } catch {
      self.errorMessage = String(
        localized: "Failed to configure audio session.",
        comment: "Error when audio session setup fails",
      )
      return false
    }
  }

  private func startAudioCapture() {
    let inputNode = self.session.audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    if let fileName = currentAudioFileName {
      _ = self.audioRecorder.startRecording(fileName: fileName, format: recordingFormat)
    }

    self.session.activateTap(accumulator: self.accumulator, recorder: self.audioRecorder)
  }

}

extension SpeechRecognitionService {

  func setupDarwinObservers() {
    self.setupDictationObservers()
    self.sessionStatusObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.requestSessionStatus
    ) { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let active = self.session.isSessionActive
        let recording = self.isRecording
        if active {
          TranscriptionBridge.postDarwinNotification(DarwinNotificationName.sessionStarted)
        }
        if recording {
          TranscriptionBridge.postDarwinNotification(DarwinNotificationName.dictationStarted)
        }
      }
    }
  }

  func setupSessionCallbacks() {
    self.session.onInterruptionBegan = { [weak self] in
      Task { @MainActor [weak self] in await self?.stopRecording() }
    }
    self.session.onSessionEnded = { [weak self] in
      Task { @MainActor [weak self] in await self?.stopRecording() }
    }
  }

  func forwardSessionState() {
    self.sessionCancellable = self.session.$isSessionActive
      .receive(on: DispatchQueue.main)
      .sink { [weak self] active in
        self?.isSessionActive = active
      }
  }

  private func hasValidSessionToken(caller _: String) -> Bool {
    let tokenSettings = SharedSettings()
    tokenSettings.synchronize()
    guard tokenSettings.dictationSessionToken != nil else {
      return false
    }
    return true
  }

  private func setupDictationObservers() {
    self.requestStartObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.requestStartDictation
    ) { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else {
          return
        }
        guard self.hasValidSessionToken(caller: "requestStartDictation") else { return }
        let _ = String(describing: self.activeLoadState)
        await self.startRecordingAfterModelLoad()
      }
    }

    self.requestStopObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.requestStopDictation
    ) { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else {
          return
        }
        guard self.hasValidSessionToken(caller: "requestStopDictation") else { return }
        await self.stopRecording()
      }
    }
  }

}

extension SpeechRecognitionService: ModelLoading {

  func loadModel(variant: ModelVariant, from url: URL) async -> Bool {
    switch variant.engine {
    case .whisperKit:
      await self.whisperService.loadModel(variant: variant, from: url.path)
      return self.whisperService.loadState == .loaded

    case .parakeet:
      let version = self.parakeetModelVersion(for: variant)
      await self.parakeetService.loadModel(from: url, version: version)
      return self.parakeetService.loadState == .loaded

    case .moonshine:
      guard let arch = variant.moonshineModelArch else { return false }
      await self.moonshineService.loadModel(from: url.path, archName: arch)
      return self.moonshineService.loadState == .loaded
    }
  }
}
