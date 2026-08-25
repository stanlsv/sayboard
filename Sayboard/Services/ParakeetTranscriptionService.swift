
import CoreML
@preconcurrency import FluidAudio
import Foundation

@MainActor
final class ParakeetTranscriptionService: ObservableObject {

  @Published private(set) var loadState = ModelLoadState.unloaded

  func transcribe(audioSamples: [Float]) async -> TranscriptionResult {
    guard let asrManager, loadState == .loaded else {
      let state = String(describing: loadState)
      DiagnosticLog.write("parakeet: ABORT — loadState=\(state)")
      return .failed("model not loaded (\(state))")
    }
    guard !audioSamples.isEmpty else { return .failed("no audio samples") }

    do {
      var decoderState = try TdtDecoderState()
      let result = try await asrManager.transcribe(
        audioSamples,
        decoderState: &decoderState,
        language: Self.scriptHint(),
      )
      let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !text.isEmpty else {
        DiagnosticLog.write("parakeet: NO SPEECH — model produced empty text")
        return .noSpeech
      }

      let timings = result.tokenTimings
      return .text(TranscriptionOutput(
        text: text,
        firstWordStart: timings?.first.map { Float($0.startTime) },
        lastWordEnd: timings?.last.map { Float($0.endTime) },
      ))
    } catch ASRError.invalidAudioData {
      DiagnosticLog.write("parakeet: NO SPEECH — shorter than the 0.3s minimum")
      return .noSpeech
    } catch {
      DiagnosticLog.write("parakeet: THREW \(type(of: error)): \(error)")
      return .failed(error.localizedDescription)
    }
  }

  func loadModel(from directory: URL, version: AsrModelVersion) async {
    if let existing = self.loadTask {
      await existing.value
      return
    }

    self.loadGeneration += 1
    let expectedGen = self.loadGeneration
    self.loadState = .loading
    let computeMode = OperatingSystem.isBackgroundNeuralEngineBlocked ? "cpuOnly (iOS 27 ANE gate)" : "default (ANE)"
    DiagnosticLog.write("parakeet: model load start, compute=\(computeMode)")

    let loadDirectory = Self.normalizedModelDirectory(directory)

    let task = Task<Void, Never>.detached(priority: .userInitiated) { [weak self] in
      do {
        let models = try await AsrModels.load(
          from: loadDirectory,
          configuration: Self.modelConfiguration(),
          version: version,
        )
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)

        await MainActor.run { [weak self] in
          guard let self, expectedGen == self.loadGeneration else {
            Task { await manager.cleanup() }
            return
          }
          self.asrManager = manager
          self.currentVersion = version
          self.loadState = .loaded
          DiagnosticLog.write("parakeet: model loaded")
        }
      } catch {
        let errorMessage = error.localizedDescription
        let detail = "\(type(of: error)): \(error)"
        await MainActor.run { [weak self] in
          guard let self, expectedGen == self.loadGeneration else { return }
          self.loadState = .error(errorMessage)
          DiagnosticLog.write("parakeet: MODEL LOAD FAILED \(detail)")
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

  func unloadModel() async {
    self.loadGeneration += 1
    self.loadTask?.cancel()
    self.loadTask = nil
    if let asrManager {
      await asrManager.cleanup()
    }
    self.asrManager = nil
    self.currentVersion = nil
    self.loadState = .unloaded
  }

  private var asrManager: AsrManager?
  private var currentVersion: AsrModelVersion?
  private var loadTask: Task<Void, Never>?
  private var loadGeneration = 0

  private static nonisolated func normalizedModelDirectory(_ directory: URL) -> URL {
    let current = directory.lastPathComponent
    let expected = current.replacingOccurrences(of: "-coreml", with: "")
    guard current != expected else { return directory }

    let target = directory.deletingLastPathComponent().appendingPathComponent(expected)
    let fm = FileManager.default
    if fm.fileExists(atPath: target.path) {
      return target
    }
    do {
      try fm.moveItem(at: directory, to: target)
      DiagnosticLog.write("parakeet: renamed model folder -> \(expected)")
      return target
    } catch {
      DiagnosticLog.write("parakeet: RENAME FAILED \(error)")
      return directory
    }
  }

  private static func scriptHint() -> Language? {
    let settings = SharedSettings()
    settings.synchronize()
    let preferred = settings.preferredLanguages(for: settings.selectedVariant)
    guard preferred.count == 1, let code = preferred.first else { return nil }
    return Language(rawValue: code)
  }

  private static nonisolated func modelConfiguration() -> MLModelConfiguration? {
    guard OperatingSystem.isBackgroundNeuralEngineBlocked else { return nil }
    let configuration = MLModelConfiguration()
    configuration.computeUnits = .cpuOnly
    configuration.allowLowPrecisionAccumulationOnGPU = true
    return configuration
  }
}
