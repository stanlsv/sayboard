import Accelerate
@preconcurrency import AVFoundation
import os

private struct TapState: @unchecked Sendable {
  let accumulator: AudioBufferAccumulator
  let recorder: AudioRecorder
  let converter: AVAudioConverter?
  let targetFormat: AVAudioFormat
}

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

@MainActor
final class BackgroundAudioSession: ObservableObject {

  @Published private(set) var isSessionActive = false
  private(set) var hasRecordedThisSession = false

  var onInterruptionBegan: (() -> Void)?

  var onSessionEnded: (() -> Void)?

  let audioEngine = AVAudioEngine()

  nonisolated let levelBridge = AudioLevelBridge(mode: .writer)

  nonisolated let tapDiagnostics = OSAllocatedUnfairLock<TapDiagnostics>(initialState: TapDiagnostics())

  func startSession() throws {
    guard !self.isSessionActive else {
      return
    }

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(
      .playAndRecord,
      mode: .default,
      options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothA2DP],
    )
    try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    try self.installPersistentTap()

    self.audioEngine.prepare()
    try self.audioEngine.start()

    self.isSessionActive = true
    self.settings.isSessionActive = true
    self.settings.mainAppHeartbeat = CFAbsoluteTimeGetCurrent()
    TranscriptionBridge.postDarwinNotification(DarwinNotificationName.sessionStarted)

    self.setupInterruptionObserver()
    self.resetInactivityTimer()
  }

  func endSession() {
    guard self.isSessionActive else {
      return
    }

    self.resetLevelState()
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
        sampleRate: AudioBufferMath.targetSampleRate,
        channels: 1,
        interleaved: false,
      )
    else {
      return
    }

    let needsConversion = hwFormat.sampleRate != AudioBufferMath.targetSampleRate || hwFormat.channelCount != 1
    let converter: AVAudioConverter? = needsConversion
      ? AVAudioConverter(from: hwFormat, to: targetFormat)
      : nil

    if needsConversion, converter == nil { }
    DiagnosticLog.write(
      "activateTap: hw=\(hwFormat.sampleRate)Hz/\(hwFormat.channelCount)ch "
        + "needsConversion=\(needsConversion) converter=\(converter != nil)"
    )
    self.tapDiagnostics.withLock { $0 = TapDiagnostics() }

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
    self.resetLevelState()
    self.logTapDiagnostics()
    self.resetInactivityTimer()
  }

  func updateTimeout() {
    let isCapturing = self.tapState.withLock { $0 != nil }
    guard !isCapturing else { return }
    self.resetInactivityTimer()
  }

  private let settings = SharedSettings()
  private nonisolated let tapState = OSAllocatedUnfairLock<TapState?>(initialState: nil)
  private var inactivityTimer: Timer?
  private nonisolated let lastFlushTime = OSAllocatedUnfairLock<CFAbsoluteTime>(initialState: 0)
  private nonisolated let lastHeartbeatTime = OSAllocatedUnfairLock<CFAbsoluteTime>(initialState: 0)
  private nonisolated let previousLevel = OSAllocatedUnfairLock<Float>(initialState: 0)
  private nonisolated let rmsRingBuffer = OSAllocatedUnfairLock<(buffer: [Float], index: Int)>(
    initialState: (buffer: [Float](repeating: 0, count: AudioBufferMath.rmsPreFilterWindowSize), index: 0)
  )
  private var interruptionObserver: NSObjectProtocol?

  private func resetLevelState() {
    self.previousLevel.withLock { $0 = 0 }
    self.rmsRingBuffer.withLock { state in
      state.buffer = [Float](repeating: 0, count: AudioBufferMath.rmsPreFilterWindowSize)
      state.index = 0
    }
    self.levelBridge.writeLevel(0)
    self.levelBridge.flushToDefaults()
  }

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

    let state = self.tapState
    let bridge = self.levelBridge
    let lastFlush = self.lastFlushTime
    let lastHeartbeat = self.lastHeartbeatTime
    let prevLevel = self.previousLevel
    let ringBuf = self.rmsRingBuffer
    let diagnostics = self.tapDiagnostics
    try ObjCExceptionCatcher.catchException {
      inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { @Sendable buffer, _ in
        let now = CFAbsoluteTimeGetCurrent()
        let shouldHeartbeat = lastHeartbeat.withLock { last -> Bool in
          if now - last >= 0.5 {
            last = now
            return true
          }
          return false
        }
        if shouldHeartbeat {
          AppGroup.sharedDefaults?.set(now, forKey: SharedKey.mainAppHeartbeat)
        }

        let active = state.withLock { $0 }
        guard let active else { return }

        let rms = AudioBufferMath.rms(from: buffer)
        let filtered = AudioBufferMath.preFilterRMS(min(rms * 14, 1.0), ringBuffer: ringBuf)
        bridge.writeLevel(AudioBufferMath.smoothLevel(filtered, previous: prevLevel))

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
            AudioBufferMath.resample(
              buffer,
              converter: converter,
              targetFormat: active.targetFormat,
              diagnostics: diagnostics,
            )
          } else {
            AudioBufferMath.samples(from: buffer)
          }

        if !samples.isEmpty { active.accumulator.append(samples) }

        diagnostics.withLock { diag in
          diag.buffers += 1
          diag.inputFrames += Int(buffer.frameLength)
          diag.outputFrames += samples.count
          if diag.inputSampleRate == 0 {
            diag.inputSampleRate = buffer.format.sampleRate
            diag.inputChannels = buffer.format.channelCount
          }
          if rms > diag.peakRMS { diag.peakRMS = rms }
        }
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
      break
    }
  }
}
