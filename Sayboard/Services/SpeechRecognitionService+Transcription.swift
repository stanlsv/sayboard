// SpeechRecognitionService+Transcription -- Final transcription and history saving

import Foundation

extension SpeechRecognitionService {

  func runFinalTranscription(samples: [Float]) async {
    let engine = self.settings.selectedVariant.engine

    guard !samples.isEmpty else {
      return
    }

    let output: TranscriptionOutput? =
      switch engine {
      case .whisperKit:
        await self.whisperService.transcribe(audioSamples: samples)
      case .parakeet:
        await self.parakeetService.transcribe(audioSamples: samples)
      case .moonshine:
        await self.moonshineService.transcribe(audioSamples: samples)
      }

    if let output {
      let sanitizedText = TextSanitizer.sanitize(output.text)
      self.currentTranscription = sanitizedText

      let store = AppStyleStore()
      let hostId = self.settings.hostBundleId
      let resolvedStyle = hostId.flatMap { store.style(for: $0) } ?? self.settings.defaultWritingStyle
      let formattedText = TextStyleFormatter.format(sanitizedText, style: resolvedStyle)
      let expandedText = SnippetExpander.expand(formattedText, snippets: self.settings.snippets)

      TranscriptionBridge.writeTranscription(expandedText)

      if let start = output.firstWordStart, let end = output.lastWordEnd {
        self.currentWordBoundaries = (start: start, end: end)
      } else {
        self.currentWordBoundaries = nil
      }

    } else {
      self.currentWordBoundaries = nil
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
