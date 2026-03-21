// WhisperKitTranscriptionService -- Loads WhisperKit models and transcribes audio samples

import Foundation

@preconcurrency import WhisperKit

// MARK: - ModelLoadState

enum ModelLoadState: Equatable, Sendable {
  case unloaded
  case loading
  case loaded
  case error(String)
}

// MARK: - TranscriptionOutput

struct TranscriptionOutput: Sendable {
  let text: String
  let firstWordStart: Float?
  let lastWordEnd: Float?
}

// MARK: - WhisperKitTranscriptionService

@MainActor
final class WhisperKitTranscriptionService: ObservableObject {

  // MARK: Internal

  @Published private(set) var loadState = ModelLoadState.unloaded

  /// Loads a WhisperKit model from the given folder. If a load is already in
  /// progress, subsequent callers await the same result instead of no-oping.
  func loadModel(from folderPath: String) async {
    if let existing = self.loadTask {
      await existing.value
      return
    }

    self.loadGeneration += 1
    let expectedGen = self.loadGeneration
    self.loadState = .loading

    let task = Task<Void, Never>.detached(priority: .userInitiated) { [weak self] in
      do {
        let config = WhisperKitConfig(
          modelFolder: folderPath,
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
        }
      } catch {
        let errorMessage = error.localizedDescription
        await MainActor.run { [weak self] in
          guard let self, expectedGen == self.loadGeneration else { return }
          self.loadState = .error(errorMessage)
        }
      }
    }
    self.loadTask = task
    await task.value
    self.loadTask = nil
  }

  /// Awaits a pending model load (if any). Returns immediately if not loading.
  func waitForLoad() async {
    guard let task = self.loadTask else { return }
    await task.value
  }

  func transcribe(audioSamples: [Float]) async -> TranscriptionOutput? {
    guard let whisperKit, loadState == .loaded else {
      return nil
    }
    guard !audioSamples.isEmpty else { return nil }

    do {
      let translationSettings = SharedSettings()
      translationSettings.synchronize()
      let task: DecodingTask = translationSettings.isTranslationMode ? .translate : .transcribe

      let options = DecodingOptions(
        task: task,
        detectLanguage: true,
        skipSpecialTokens: true,
        wordTimestamps: true,
      )
      let results = try await whisperKit.transcribe(
        audioArray: audioSamples,
        decodeOptions: options,
      )

      let goodSegments = results.flatMap { $0.segments }.filter { segment in
        let dominated = segment.noSpeechProb > Self.noSpeechThreshold
        let lowConf = segment.avgLogprob < Self.logProbThreshold
        let repetitive = segment.compressionRatio > Self.compressionRatioThreshold
        return !dominated && !lowConf && !repetitive
      }

      let text = goodSegments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)

      guard !text.isEmpty, text.wholeMatch(of: Self.audioEventTagPattern) == nil else { return nil }

      let allWords = goodSegments.compactMap(\.words).flatMap { $0 }
      return TranscriptionOutput(
        text: text,
        firstWordStart: allWords.first?.start,
        lastWordEnd: allWords.last?.end,
      )
    } catch {
      return nil
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

  // MARK: Private

  /// Segments with no-speech probability above this are silence — skip them.
  private static let noSpeechThreshold: Float = 0.6
  /// Segments with average log-probability below this are low-confidence — skip them.
  private static let logProbThreshold: Float = -1.0
  /// Segments with compression ratio above this are repetitive/hallucinated — skip them.
  private static let compressionRatioThreshold: Float = 2.4

  /// Whisper audio event tags: `[BLANK_AUDIO]`, `[Music]`, `(Applause)`, etc.
  /// Real speech is never just a single bracketed tag.
  private static let audioEventTagPattern = /^\s*[\[\(].+[\]\)]\s*$/

  private var whisperKit: WhisperKit?
  private var loadTask: Task<Void, Never>?
  private var loadGeneration = 0

}
