import AVFoundation
import Combine
import FluidAudio

import SwiftUI

// MARK: - ModelLoading

@MainActor
protocol ModelLoading: AnyObject {
  func loadModel(variant: ModelVariant, from url: URL) async -> Bool
}

// MARK: - SpeechRecognitionService

// SpeechRecognitionService -- On-device speech-to-text powered by WhisperKit or Parakeet.
// Records audio via BackgroundAudioSession, accumulates 16kHz samples,
// and transcribes on stop using the active engine's transcription service.

@MainActor
final class SpeechRecognitionService: ObservableObject {

  // MARK: Lifecycle

  init() {
    self.setupDarwinObservers()
    self.setupSessionCallbacks()
    self.forwardSessionState()
  }

  // MARK: Internal

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

  /// True while `stopRecording()` is awaiting model load / transcription.
  /// Prevents concurrent start calls from resetting the accumulator.
  private(set) var isStopping = false

  var activeLoadState: ModelLoadState {
    switch self.settings.selectedVariant.engine {
    case .whisperKit: self.whisperService.loadState
    case .parakeet: self.parakeetService.loadState
    case .moonshine: self.moonshineService.loadState
    }
  }

  func startRecording() {
    let loadState = String(describing: self.activeLoadState)
    let micAuth = self.settings.isMicrophoneAuthorized
    let sessionActive = self.session.isSessionActive
    let engineRunning = self.session.audioEngine.isRunning

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
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.dictationStarted)
  }

  /// Starts audio capture without requiring a loaded model.
  func startCapture() {
    let micAuth = self.settings.isMicrophoneAuthorized
    let sessionActive = self.session.isSessionActive
    let engineRunning = self.session.audioEngine.isRunning
    let loadState = String(describing: self.activeLoadState)

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
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.dictationStarted)
  }

  func stopRecording() async {
    let loadState = String(describing: self.activeLoadState)

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

    self.session.deactivateTap()
    // Snapshot samples before any await -- a concurrent startCapture() could
    // reset the accumulator while we wait for the model to load.
    let savedSamples = self.accumulator.samples

    // Wait for model to finish loading before transcribing (don't discard audio).
    // Also attempt to load if the model is unloaded or errored -- the user recorded
    // audio via startCapture() which doesn't require a loaded model.
    if self.activeLoadState != .loaded {
      let state = String(describing: self.activeLoadState)
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

  /// Unloads the current model and loads the new one. The audio session stays alive.
  func reloadModel(variant: ModelVariant, folderURL: URL?) async {
    await self.unloadAllEngines()
    guard let folderURL else { return }
    _ = await self.loadModel(variant: variant, from: folderURL)
  }

  /// Unloads all STT models to free memory for LLM processing.
  /// Does NOT end the audio session so it can resume dictation later.
  func unloadForLLMProcessing() async {
    if self.isRecording {
      await self.stopRecording()
    }
    await self.unloadAllEngines()
  }

  /// Unloads all models and ends the audio session (no models left).
  func deactivateCompletely() async {
    await self.unloadAllEngines()
    self.session.endSession()
  }

  /// Ensures the active engine's model is loaded, then starts recording.
  /// Used by deep link and Darwin notification handlers where the model
  /// may not yet be in memory.
  ///
  /// If the model is already loaded, starts recording immediately.
  /// If not, starts audio capture first (buffers audio, posts dictationStarted
  /// to keyboard) then loads the model in the background.
  func startRecordingAfterModelLoad() async {
    let loadState = String(describing: self.activeLoadState)
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

  // MARK: Private

  private var errorMessage: String?
  private var sessionCancellable: AnyCancellable?

  private var requestStartObserver: DarwinNotificationObserver?
  private var requestStopObserver: DarwinNotificationObserver?
  private var sessionStatusObserver: DarwinNotificationObserver?

  /// Awaits a pending model load on the active engine.
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
    self.parakeetService.unloadModel()
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

// MARK: - Darwin Observers

extension SpeechRecognitionService {

  // MARK: Internal

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

  // MARK: Private

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
        let state = String(describing: self.activeLoadState)
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

// MARK: ModelLoading

extension SpeechRecognitionService: ModelLoading {

  func loadModel(variant: ModelVariant, from url: URL) async -> Bool {
    switch variant.engine {
    case .whisperKit:
      await self.whisperService.loadModel(from: url.path)
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
