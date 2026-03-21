import Accelerate
@preconcurrency import AVFoundation
import os

// AudioRecorder -- Writes PCM audio buffers to a CAF file

final class AudioRecorder: Sendable {

  // MARK: Internal

  struct RecordingResult: Sendable {
    let url: URL
    let duration: TimeInterval
    let waveformSamples: [Float]
  }

  func startRecording(fileName: String, format: AVAudioFormat) -> URL? {
    guard let directory = HistoryStore.shared.audioDirectoryURL else { return nil }
    let fileURL = directory.appendingPathComponent(fileName)
    do {
      let file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUnlessOpen],
        ofItemAtPath: fileURL.path,
      )
      self.state.withLock { $0 = MutableState(audioFile: file, startTime: Date()) }
      return fileURL
    } catch {
      return nil
    }
  }

  func appendBuffer(_ buffer: AVAudioPCMBuffer) {
    self.state.withLock { current in
      try? current?.audioFile.write(from: buffer)

      guard let channelData = buffer.floatChannelData else { return }
      let frameCount = Int(buffer.frameLength)
      guard frameCount > 0 else { return }

      var peak: Float = 0
      vDSP_maxmgv(channelData[0], 1, &peak, vDSP_Length(frameCount))
      current?.bufferPeaks.append(peak)
    }
  }

  func stopRecording() -> RecordingResult? {
    let snapshot = self.state.withLock { current -> MutableState? in
      let value = current
      current = nil
      return value
    }
    guard let snapshot else { return nil }
    let duration = Date().timeIntervalSince(snapshot.startTime)
    let url = snapshot.audioFile.url
    let samples = Self.downsamplePeaks(snapshot.bufferPeaks, to: self.waveformSampleCount)
    return RecordingResult(url: url, duration: duration, waveformSamples: samples)
  }

  // MARK: Private

  private struct MutableState {
    let audioFile: AVAudioFile
    let startTime: Date
    var bufferPeaks: ContiguousArray<Float> = []
  }

  private let waveformSampleCount = 128

  private let state = OSAllocatedUnfairLock<MutableState?>(initialState: nil)

  /// Downsamples raw per-buffer peaks to a fixed number of bins via max-pooling,
  /// then converts to DSWaveformImage convention (0 = loud, 1 = silent).
  private static func downsamplePeaks(
    _ peaks: ContiguousArray<Float>,
    to targetCount: Int,
  ) -> [Float] {
    guard !peaks.isEmpty else {
      return Array(repeating: Float(1), count: targetCount)
    }

    let sourceCount = peaks.count
    guard sourceCount > targetCount else {
      return peaks.map { 1 - min($0, 1) }
    }

    var result = [Float](repeating: 1, count: targetCount)
    let binSize = Float(sourceCount) / Float(targetCount)

    for bin in 0..<targetCount {
      let start = Int(Float(bin) * binSize)
      let end = min(Int(Float(bin + 1) * binSize), sourceCount)
      guard start < end else { continue }

      var maxVal: Float = 0
      peaks.withUnsafeBufferPointer { ptr in
        guard let base = ptr.baseAddress else { return }
        vDSP_maxmgv(base + start, 1, &maxVal, vDSP_Length(end - start))
      }
      result[bin] = 1 - min(maxVal, 1)
    }

    return result
  }
}
