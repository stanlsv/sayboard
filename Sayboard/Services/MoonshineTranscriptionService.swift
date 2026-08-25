
import Foundation
@preconcurrency import MoonshineVoice

private let defaultSampleRate: Int32 = 16_000

@MainActor
final class MoonshineTranscriptionService: ObservableObject {

  @Published private(set) var loadState = ModelLoadState.unloaded

  func transcribe(audioSamples: [Float]) async -> TranscriptionResult {
    guard let transcriber, loadState == .loaded else {
      let state = String(describing: loadState)
      DiagnosticLog.write("moonshine: ABORT — loadState=\(state)")
      return .failed("model not loaded (\(state))")
    }
    guard !audioSamples.isEmpty else { return .failed("no audio samples") }

    nonisolated(unsafe) let runner = transcriber
    let result = await Self.transcribeOffMain(runner: runner, audioSamples: audioSamples)

    switch result {
    case .text(_):
      break

    case .noSpeech:
      DiagnosticLog.write("moonshine: NO SPEECH — empty transcript")

    case .failed(let reason):
      DiagnosticLog.write("moonshine: FAILED \(reason)")
    }
    return result
  }

  func loadModel(from directoryPath: String, archName: String) async {
    guard let modelArch = Self.resolveArch(archName) else {
      self.loadState = .error("Unknown model architecture: \(archName)")
      return
    }
    await self.loadModelInternal(from: directoryPath, archRawValue: modelArch.rawValue)
  }

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

  private var transcriber: Transcriber?
  private var loadTask: Task<Void, Never>?
  private var loadGeneration = 0

  private static nonisolated func transcribeOffMain(
    runner: Transcriber,
    audioSamples: [Float],
  ) async -> TranscriptionResult {
    do {
      let transcript = try runner.transcribeWithoutStreaming(
        audioData: audioSamples,
        sampleRate: defaultSampleRate,
      )
      let lines = transcript.lines
      let text = lines.map(\.text).joined(separator: " ")
      guard !text.isEmpty else { return .noSpeech }
      let firstStart = lines.first?.startTime ?? 0
      let lastLine = lines.last
      let lastEnd = (lastLine?.startTime ?? 0) + (lastLine?.duration ?? 0)
      return .text(TranscriptionOutput(text: text, firstWordStart: firstStart, lastWordEnd: lastEnd))
    } catch {
      DiagnosticLog.write("moonshine: THREW \(type(of: error)): \(error)")
      return .failed(error.localizedDescription)
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

private enum MoonshineLoadError: LocalizedError {
  case invalidArch

  var errorDescription: String? {
    switch self {
    case .invalidArch: "Invalid Moonshine model architecture"
    }
  }
}
