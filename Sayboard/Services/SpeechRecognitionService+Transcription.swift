
import Accelerate
import Foundation

extension SpeechRecognitionService {

  func reportSignalStats(samples: [Float], engine: String, loadState: String) {
    var peak: Float = 0
    var mean: Float = 0
    vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
    vDSP_rmsqv(samples, 1, &mean, vDSP_Length(samples.count))
    let assumedDuration = Double(samples.count) / 16_000
    DiagnosticLog.write(
      "transcribe: engine=\(engine) load=\(loadState) samples=\(samples.count) "
        + "peak=\(peak) rms=\(mean) assumedDuration=\(String(format: "%.2f", assumedDuration))s"
    )
  }

  func styled(_ text: String) -> String {
    let store = AppStyleStore()
    let resolvedStyle = self.settings.hostBundleId.flatMap { store.style(for: $0) }
      ?? self.settings.defaultWritingStyle
    let formatted = TextStyleFormatter.format(text, style: resolvedStyle)
    return SnippetExpander.expand(formatted, snippets: self.settings.snippets)
  }

  func runFinalTranscription(samples: [Float]) async {
    let engine = self.settings.selectedVariant.engine
    let loadState = String(describing: self.activeLoadState)

    guard !samples.isEmpty else {
      DiagnosticLog.write("transcribe: ABORT — 0 samples reached the model")
      self.settings.lastDictationOutcome = .engineFailed
      return
    }

    self.reportSignalStats(samples: samples, engine: String(describing: engine), loadState: loadState)

    let result: TranscriptionResult =
      switch engine {
      case .whisperKit:
        await self.whisperService.transcribe(audioSamples: samples)
      case .parakeet:
        await self.parakeetService.transcribe(audioSamples: samples)
      case .moonshine:
        await self.moonshineService.transcribe(audioSamples: samples)
      }

    switch result {
    case .text: self.settings.lastDictationOutcome = nil
    case .noSpeech: self.settings.lastDictationOutcome = .noSpeech
    case .failed: self.settings.lastDictationOutcome = .engineFailed
    }

    if case .text(let output) = result {
      let sanitizedText = TextSanitizer.sanitize(output.text)
      self.currentTranscription = sanitizedText

      let bridgeText = self.styled(sanitizedText)
      TranscriptionBridge.writeTranscription(bridgeText)

      if let start = output.firstWordStart, let end = output.lastWordEnd {
        self.currentWordBoundaries = (start: start, end: end)
      } else {
        self.currentWordBoundaries = nil
      }

      DiagnosticLog.write("transcribe: SUCCESS \(bridgeText.count) chars -> bridge")
    } else {
      self.currentWordBoundaries = nil
      let reason = if case .failed(let message) = result { message } else { "no speech detected" }
      DiagnosticLog.write("transcribe: NO TEXT — \(reason)")
    }
  }

  func saveHistoryRecord() {
    guard let fileName = currentAudioFileName else { return }
    guard let result = audioRecorder.stopRecording() else { return }

    let transcription = self.currentTranscription
    guard !transcription.isEmpty else {
      if let url = HistoryStore.shared.audioFileURL(for: fileName) {
        try? FileManager.default.removeItem(at: url)
      }
      return
    }

    var duration = result.duration
    var waveformSamples = result.waveformSamples

    if let bounds = currentWordBoundaries {
      if
        let trimResult = AudioTrimmer.trimToSpeech(
          fileURL: result.url,
          firstWordStart: bounds.start,
          lastWordEnd: bounds.end,
        )
      {
        duration = trimResult.duration
        waveformSamples = trimResult.waveformSamples
      }
    }
    self.currentWordBoundaries = nil

    let record = HistoryRecord(
      id: UUID(),
      date: Date(),
      duration: duration,
      transcription: transcription,
      audioFileName: fileName,
      waveformSamples: waveformSamples,
    )
    HistoryStore.shared.saveRecord(record)
    HistoryStore.shared.applyRetentionPolicy()
    self.currentAudioFileName = nil
    self.historySaveGeneration += 1
  }
}
