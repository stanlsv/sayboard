
import CoreML
import Foundation

@preconcurrency import WhisperKit

enum ModelLoadState: Equatable, Sendable {
  case unloaded
  case loading
  case loaded
  case error(String)
}

struct TranscriptionOutput: Sendable {
  let text: String
  let firstWordStart: Float?
  let lastWordEnd: Float?
}

enum TranscriptionResult: Sendable {
  case text(TranscriptionOutput)
  case noSpeech
  case failed(String)
}

@MainActor
final class WhisperKitTranscriptionService: ObservableObject {

  @Published private(set) var loadState = ModelLoadState.unloaded

  func loadModel(from folderPath: String) async {
    if let existing = self.loadTask {
      await existing.value
      return
    }

    self.loadGeneration += 1
    let expectedGen = self.loadGeneration
    self.loadState = .loading
    let computeMode = OperatingSystem.isBackgroundNeuralEngineBlocked ? "cpuOnly (iOS 27 ANE gate)" : "default (ANE)"
    DiagnosticLog.write("whisper: model load start, compute=\(computeMode)")

    let task = Task<Void, Never>.detached(priority: .userInitiated) { [weak self] in
      do {
        let config = WhisperKitConfig(
          modelFolder: folderPath,
          computeOptions: Self.computeOptions(),
          load: true,
          download: false,
        )
        let kit = try await WhisperKit(config)

        await MainActor.run { [weak self] in
          guard let self, expectedGen == self.loadGeneration else {
            Task { await kit.unloadModels() }
            return
          }
          self.whisperKit = kit
          self.loadState = .loaded
          DiagnosticLog.write("whisper: model loaded")
        }
      } catch {
        let errorMessage = error.localizedDescription
        let errorDetail = "\(type(of: error)): \(error)"
        await MainActor.run { [weak self] in
          guard let self, expectedGen == self.loadGeneration else { return }
          self.loadState = .error(errorMessage)
          DiagnosticLog.write("whisper: MODEL LOAD FAILED \(errorDetail)")
        }
      }
    }
    self.loadTask = task
    await task.value
    self.loadTask = nil
  }

  func waitForLoad() async {
    guard let task = self.loadTask else { return }
    await task.value
  }

  func transcribe(audioSamples: [Float]) async -> TranscriptionResult {
    guard let whisperKit, self.loadState == .loaded else {
      let state = String(describing: loadState)
      let hasInstance = self.whisperKit != nil
      DiagnosticLog.write("whisper: ABORT — instance=\(hasInstance) loadState=\(state)")
      return .failed("model not loaded (instance=\(hasInstance) state=\(state))")
    }
    guard !audioSamples.isEmpty else {
      DiagnosticLog.write("whisper: ABORT — 0 samples")
      return .failed("no audio samples")
    }

    DiagnosticLog.write("whisper: inference start, \(audioSamples.count) samples")
    do {
      let options = self.makeDecodingOptions()
      let results = try await whisperKit.transcribe(
        audioArray: audioSamples,
        decodeOptions: options,
      )
      let detectedLang = results.first?.language ?? "unknown"

      let allSegments = results.flatMap { $0.segments }
      let goodSegments = Self.keepableSegments(from: allSegments)

      let text = goodSegments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)

      DiagnosticLog.write("whisper: \(allSegments.count) seg, \(goodSegments.count) kept, \(text.count) chars, \(detectedLang)")

      guard !text.isEmpty, text.wholeMatch(of: Self.audioEventTagPattern) == nil else {
        DiagnosticLog.write("whisper: NO SPEECH — empty after filtering, or audio-event tag only")
        return .noSpeech
      }

      let allWords = goodSegments.compactMap(\.words).flatMap { $0 }
      return .text(TranscriptionOutput(
        text: text,
        firstWordStart: allWords.first?.start,
        lastWordEnd: allWords.last?.end,
      ))
    } catch {
      DiagnosticLog.write("whisper: THREW \(type(of: error)): \(error)")
      return .failed(error.localizedDescription)
    }
  }

  func unloadModel() async {
    self.loadGeneration += 1
    self.loadTask?.cancel()
    self.loadTask = nil
    if let whisperKit {
      await whisperKit.unloadModels()
    }
    whisperKit = nil
    self.loadState = .unloaded
  }

  private static let noSpeechThreshold: Float = 0.6
  private static let logProbThreshold: Float = -1.0
  private static let compressionRatioThreshold: Float = 2.4

  private static let audioEventTagPattern = /^\s*[\[\(].+[\]\)]\s*$/

  private var whisperKit: WhisperKit?
  private var loadTask: Task<Void, Never>?
  private var loadGeneration = 0

  private static nonisolated func computeOptions() -> ModelComputeOptions? {
    guard OperatingSystem.isBackgroundNeuralEngineBlocked else { return nil }
    return ModelComputeOptions(
      melCompute: .cpuOnly,
      audioEncoderCompute: .cpuOnly,
      textDecoderCompute: .cpuOnly,
    )
  }

  private static func keepableSegments(from segments: [TranscriptionSegment]) -> [TranscriptionSegment] {
    segments.filter { segment in
      let dominated = segment.noSpeechProb > Self.noSpeechThreshold
      let lowConf = segment.avgLogprob < Self.logProbThreshold
      let repetitive = segment.compressionRatio > Self.compressionRatioThreshold
      return !dominated && !lowConf && !repetitive
    }
  }

  private func makeDecodingOptions() -> DecodingOptions {
    let settings = SharedSettings()
    settings.synchronize()
    let task: DecodingTask = settings.isTranslationMode ? .translate : .transcribe

    let preferred = settings.preferredLanguages(for: settings.selectedVariant)
    let lockedLanguage: String? = preferred.count == 1 ? preferred.first : nil
    if !preferred.isEmpty { }

    return DecodingOptions(
      task: task,
      language: lockedLanguage,
      detectLanguage: lockedLanguage == nil,
      skipSpecialTokens: true,
      wordTimestamps: true,
    )
  }

}
