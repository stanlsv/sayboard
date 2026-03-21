import Accelerate
@preconcurrency import AVFoundation
import os

// BackgroundAudioSession -- Persistent audio engine that keeps the app alive in background.
// The tap stays installed at all times; when recording, buffers are forwarded
// to the audio buffer accumulator + audio recorder. When idle, buffers are discarded.

// MARK: - TapState

// Thread-safe: fields are immutable lets; AudioBufferAccumulator and AudioRecorder
// are both Sendable and safe to call from the real-time audio thread.
// swiftlint:disable:next no_unchecked_sendable
private struct TapState: @unchecked Sendable {
  let accumulator: AudioBufferAccumulator
  let recorder: AudioRecorder
  let converter: AVAudioConverter?
  let targetFormat: AVAudioFormat
}

// MARK: - AudioSessionError

enum AudioSessionError: LocalizedError {
  case noInputChannels
  case tapInstallFailed(String)

  var errorDescription: String? {
    switch self {
    case .noInputChannels:
      "No audio input available. Microphone access may be restricted."
    case .tapInstallFailed(let reason):
      "Audio tap failed: \(reason)"
    }
  }
}

// MARK: - Resampling

private let whisperKitSampleRate: Double = 16_000

private func resampleBuffer(
  _ buffer: AVAudioPCMBuffer,
  converter: AVAudioConverter,
  targetFormat: AVAudioFormat,
) -> [Float] {
  let frameCount = AVAudioFrameCount(
    Double(buffer.frameLength) * whisperKitSampleRate / buffer.format.sampleRate
  )
  guard
    let convertedBuffer = AVAudioPCMBuffer(
      pcmFormat: targetFormat,
      frameCapacity: frameCount + 1,
    )
  else { return [] }

  let gotData = OSAllocatedUnfairLock(initialState: false)
  let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
    let alreadyProvided = gotData.withLock { current -> Bool in
      if current { return true }
      current = true
      return false
    }
    if alreadyProvided {
      outStatus.pointee = .noDataNow
      return nil
    }
    outStatus.pointee = .haveData
    return buffer
  }

  var error: NSError?
  converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
  guard error == nil, convertedBuffer.frameLength > 0 else { return [] }
  guard let channelData = convertedBuffer.floatChannelData else { return [] }
  return Array(UnsafeBufferPointer(start: channelData[0], count: Int(convertedBuffer.frameLength)))
}

/// Asymmetric EMA: fast attack (alpha 0.7) for speech onset, slow decay (0.3) for pauses.
private func smoothLevel(
  _ scaled: Float,
  previous: OSAllocatedUnfairLock<Float>,
) -> Float {
  previous.withLock { prev -> Float in
    let alpha: Float = scaled > prev ? 0.7 : 0.3
    let result = alpha * scaled + (1 - alpha) * prev
    prev = result
    return result
  }
}

private func calculateRMS(from buffer: AVAudioPCMBuffer) -> Float {
  guard let channelData = buffer.floatChannelData else { return 0 }
  var rms: Float = 0
  vDSP_rmsqv(channelData[0], 1, &rms, vDSP_Length(buffer.frameLength))
  return rms
}

private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
  guard let channelData = buffer.floatChannelData else { return [] }
  return Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
}

// MARK: - BackgroundAudioSession

@MainActor
final class BackgroundAudioSession: ObservableObject {

  // MARK: Internal

  @Published private(set) var isSessionActive = false
  private(set) var hasRecordedThisSession = false

  /// Called when audio is interrupted (e.g. phone call). Owner should stop recording.
  var onInterruptionBegan: (() -> Void)?

  /// Called when session ends (timeout, non-resumable interruption). Owner should stop recording.
  var onSessionEnded: (() -> Void)?

  let audioEngine = AVAudioEngine()

  nonisolated let levelBridge = AudioLevelBridge(mode: .writer)

  func startSession() throws {
    guard !self.isSessionActive else {
      return
    }

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
    try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    try self.installPersistentTap()

    self.audioEngine.prepare()
    try self.audioEngine.start()

    self.isSessionActive = true
    self.settings.isSessionActive = true
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.sessionStarted)

    self.setupInterruptionObserver()
    self.resetInactivityTimer()
  }

  func endSession() {
    guard self.isSessionActive else {
      return
    }

    self.previousLevel.withLock { $0 = 0 }
    self.levelBridge.writeLevel(0)
    self.levelBridge.flushToDefaults()
    self.onSessionEnded?()

    self.inactivityTimer?.invalidate()
    self.inactivityTimer = nil

    if self.audioEngine.isRunning {
      self.audioEngine.stop()
    }
    self.audioEngine.inputNode.removeTap(onBus: 0)

    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)

    self.isSessionActive = false
    self.settings.isSessionActive = false
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.sessionEnded)
    self.hasRecordedThisSession = false

    if let observer = interruptionObserver {
      NotificationCenter.default.removeObserver(observer)
      self.interruptionObserver = nil
    }
  }

  func activateTap(accumulator: AudioBufferAccumulator, recorder: AudioRecorder) {
    let inputNode = self.audioEngine.inputNode
    let hwFormat = inputNode.outputFormat(forBus: 0)

    guard
      let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: whisperKitSampleRate,
        channels: 1,
        interleaved: false,
      )
    else {
      return
    }

    let needsConversion = hwFormat.sampleRate != whisperKitSampleRate || hwFormat.channelCount != 1
    let converter: AVAudioConverter? = needsConversion
      ? AVAudioConverter(from: hwFormat, to: targetFormat)
      : nil

    self.tapState.withLock {
      $0 = TapState(
        accumulator: accumulator,
        recorder: recorder,
        converter: converter,
        targetFormat: targetFormat,
      )
    }
    self.hasRecordedThisSession = true
    self.cancelInactivityTimer()
  }

  func deactivateTap() {
    self.tapState.withLock { $0 = nil }
    self.previousLevel.withLock { $0 = 0 }
    self.levelBridge.writeLevel(0)
    self.levelBridge.flushToDefaults()
    self.resetInactivityTimer()
  }

  /// Re-reads auto-stop policy from settings and reschedules the inactivity timer.
  func updateTimeout() {
    let isCapturing = self.tapState.withLock { $0 != nil }
    guard !isCapturing else { return }
    self.resetInactivityTimer()
  }

  // MARK: Private

  private let settings = SharedSettings()
  private nonisolated let tapState = OSAllocatedUnfairLock<TapState?>(initialState: nil)
  private var inactivityTimer: Timer?
  private nonisolated let lastFlushTime = OSAllocatedUnfairLock<CFAbsoluteTime>(initialState: 0)
  private nonisolated let previousLevel = OSAllocatedUnfairLock<Float>(initialState: 0)
  private var interruptionObserver: NSObjectProtocol?

  private func cancelInactivityTimer() {
    self.inactivityTimer?.invalidate()
    self.inactivityTimer = nil
  }

  private func installPersistentTap() throws {
    let inputNode = self.audioEngine.inputNode
    let hwFormat = inputNode.outputFormat(forBus: 0)

    guard hwFormat.channelCount > 0, hwFormat.sampleRate > 0 else {
      throw AudioSessionError.noInputChannels
    }

    inputNode.removeTap(onBus: 0)

    // installTap can throw an ObjC NSException (not a Swift Error) on format
    // mismatch or audio graph issues. ObjCExceptionCatcher converts it to a
    // Swift Error so the caller can handle it gracefully instead of crashing.
    let state = self.tapState
    let bridge = self.levelBridge
    let lastFlush = self.lastFlushTime
    let prevLevel = self.previousLevel
    try ObjCExceptionCatcher.catchException {
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { @Sendable buffer, _ in
        let active = state.withLock { $0 }
        guard let active else { return }

        let rms = calculateRMS(from: buffer)
        bridge.writeLevel(smoothLevel(min(rms * 14, 1.0), previous: prevLevel))

        // Flush to UserDefaults directly from the audio thread (~30Hz throttle).
        // Timer.scheduledTimer does not fire when the app is backgrounded;
        // the audio thread always runs while the session is active.
        let now = CFAbsoluteTimeGetCurrent()
        let shouldFlush = lastFlush.withLock { last -> Bool in
          if now - last >= 1.0 / 30.0 {
            last = now
            return true
          }
          return false
        }
        if shouldFlush {
          bridge.flushToDefaults()
        }

        active.recorder.appendBuffer(buffer)

        let samples: [Float] =
          if let converter = active.converter {
            resampleBuffer(buffer, converter: converter, targetFormat: active.targetFormat)
          } else {
            extractSamples(from: buffer)
          }

        if !samples.isEmpty { active.accumulator.append(samples) }
      }
    }
  }

  private func resetInactivityTimer() {
    self.inactivityTimer?.invalidate()
    guard self.isSessionActive else {
      self.inactivityTimer = nil
      return
    }
    let policy = self.settings.sessionAutoStopPolicy
    guard let timeout = policy.timeoutSeconds else {
      self.inactivityTimer = nil
      return
    }
    self.inactivityTimer = Timer.scheduledTimer(
      withTimeInterval: timeout,
      repeats: false,
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.endSession()
      }
    }
  }

  private func setupInterruptionObserver() {
    self.interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main,
    ) { [weak self] notification in
      // Extract values before crossing isolation boundary
      let userInfo = notification.userInfo
      let typeValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
      let optionsValue = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
      Task { @MainActor [weak self] in
        self?.handleInterruption(typeValue: typeValue, optionsValue: optionsValue)
      }
    }
  }

  private func handleInterruption(typeValue: UInt?, optionsValue: UInt?) {
    guard
      let typeValue,
      let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else {
      return
    }

    switch type {
    case .began:
      self.deactivateTap()
      self.onInterruptionBegan?()

    case .ended:
      let shouldResume = optionsValue.map {
        AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume)
      } ?? false
      guard shouldResume else {
        self.endSession()
        return
      }
      do {
        try self.audioEngine.start()
        self.resetInactivityTimer()
      } catch {
        self.endSession()
      }

    @unknown default:
    }
  }
}
