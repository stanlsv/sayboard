// MoonshineTranscriptionService -- Loads Moonshine ONNX models and transcribes audio samples

import Foundation
@preconcurrency import MoonshineVoice

private let defaultSampleRate: Int32 = 16_000

// MARK: - MoonshineTranscriptionService

@MainActor
final class MoonshineTranscriptionService: ObservableObject {

  // MARK: Internal

  @Published private(set) var loadState = ModelLoadState.unloaded

  func transcribe(audioSamples: [Float]) async -> TranscriptionOutput? {
    guard let transcriber, loadState == .loaded else {
      return nil
    }
    guard !audioSamples.isEmpty else { return nil }

    // Run CPU-intensive transcription off the main actor.
    nonisolated(unsafe) let runner = transcriber
    let output = await Self.transcribeOffMain(runner: runner, audioSamples: audioSamples)

    if let output {
    } else { }
    return output
  }

  /// Loads a Moonshine model from a local directory.
  /// - Parameters:
  ///   - directoryPath: Path to the directory containing .ort model files.
  ///   - archName: Architecture name from `ModelVariant.moonshineModelArch` (e.g. "tiny", "base").
  func loadModel(from directoryPath: String, archName: String) async {
    guard let modelArch = Self.resolveArch(archName) else {
      self.loadState = .error("Unknown model architecture: \(archName)")
      return
    }
    await self.loadModelInternal(from: directoryPath, archRawValue: modelArch.rawValue)
  }

  /// Awaits a pending model load (if any). Returns immediately if not loading.
  func waitForLoad() async {
    guard let task = self.loadTask else { return }
    await task.value
  }

  func unloadModel() {
    self.loadGeneration += 1
    self.loadTask?.cancel()
    self.loadTask = nil
    self.transcriber?.close()
    self.transcriber = nil
    self.loadState = .unloaded
  }

  // MARK: Private

  private var transcriber: Transcriber?
  private var loadTask: Task<Void, Never>?
  private var loadGeneration = 0

  private static nonisolated func transcribeOffMain(
    runner: Transcriber,
    audioSamples: [Float],
  ) async -> TranscriptionOutput? {
    do {
      let transcript = try runner.transcribeWithoutStreaming(
        audioData: audioSamples,
        sampleRate: defaultSampleRate,
      )
      let lines = transcript.lines
      let text = lines.map(\.text).joined(separator: " ")
      guard !text.isEmpty else { return nil }
      let firstStart = lines.first?.startTime ?? 0
      let lastLine = lines.last
      let lastEnd = (lastLine?.startTime ?? 0) + (lastLine?.duration ?? 0)
      return TranscriptionOutput(text: text, firstWordStart: firstStart, lastWordEnd: lastEnd)
    } catch {
      return nil
    }
  }

  private static func resolveArch(_ name: String) -> ModelArch? {
    switch name {
    case "tiny": .tiny
    case "base": .base
    case "tinyStreaming": .tinyStreaming
    case "smallStreaming": .smallStreaming
    case "mediumStreaming": .mediumStreaming
    default: nil
    }
  }

  private func loadModelInternal(from directoryPath: String, archRawValue: UInt32) async {
    if let existing = self.loadTask {
      await existing.value
      return
    }

    self.loadGeneration += 1
    let expectedGen = self.loadGeneration
    self.loadState = .loading

    let task = Task<Void, Never>.detached(priority: .userInitiated) { [weak self] in
      do {
        guard let arch = ModelArch(rawValue: archRawValue) else {
          throw MoonshineLoadError.invalidArch
        }
        let loaded = try Transcriber(modelPath: directoryPath, modelArch: arch)
        nonisolated(unsafe) let transcriberRef = loaded

        await MainActor.run { [weak self] in
          guard let self, expectedGen == self.loadGeneration else {
            transcriberRef.close()
            return
          }
          self.transcriber = transcriberRef
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

}

// MARK: - MoonshineLoadError

private enum MoonshineLoadError: LocalizedError {
  case invalidArch

  var errorDescription: String? {
    switch self {
    case .invalidArch: "Invalid Moonshine model architecture"
    }
  }
}
