// ParakeetTranscriptionService -- Loads FluidAudio Parakeet models and transcribes audio samples

@preconcurrency import FluidAudio
import Foundation

// MARK: - ParakeetTranscriptionService

@MainActor
final class ParakeetTranscriptionService: ObservableObject {

  // MARK: Internal

  @Published private(set) var loadState = ModelLoadState.unloaded

  func transcribe(audioSamples: [Float]) async -> TranscriptionOutput? {
    guard let asrManager, loadState == .loaded else {
      return nil
    }
    guard !audioSamples.isEmpty else { return nil }

    do {
      nonisolated(unsafe) let manager = asrManager
      let result = try await manager.transcribe(audioSamples, source: .microphone)
      let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !text.isEmpty else { return nil }

      let timings = result.tokenTimings
      return TranscriptionOutput(
        text: text,
        firstWordStart: timings?.first.map { Float($0.startTime) },
        lastWordEnd: timings?.last.map { Float($0.endTime) },
      )
    } catch {
      return nil
    }
  }

  /// Loads a Parakeet model from a local directory (downloaded via R2).
  func loadModel(from directory: URL, version: AsrModelVersion) async {
    if let existing = self.loadTask {
      await existing.value
      return
    }

    self.loadGeneration += 1
    let expectedGen = self.loadGeneration
    self.loadState = .loading

    let task = Task<Void, Never>.detached(priority: .userInitiated) { [weak self] in
      do {
        let models = try await AsrModels.load(from: directory, version: version)
        let manager = AsrManager(config: .default)
        try await manager.initialize(models: models)

        await MainActor.run { [weak self] in
          guard let self, expectedGen == self.loadGeneration else {
            manager.cleanup()
            return
          }
          self.asrManager = manager
          self.currentVersion = version
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

  func unloadModel() {
    self.loadGeneration += 1
    self.loadTask?.cancel()
    self.loadTask = nil
    self.asrManager?.cleanup()
    self.asrManager = nil
    self.currentVersion = nil
    self.loadState = .unloaded
  }

  // MARK: Private

  private var asrManager: AsrManager?
  private var currentVersion: AsrModelVersion?
  private var loadTask: Task<Void, Never>?
  private var loadGeneration = 0
}
