// AudioTrimmer -- Trims CAF audio files to speech boundaries with fade-in/out

import Accelerate
@preconcurrency import AVFoundation

// MARK: - TrimResult

struct TrimResult: Sendable {
  let duration: TimeInterval
  let waveformSamples: [Float]
}

// MARK: - AudioTrimmer

enum AudioTrimmer {

  // MARK: Internal

  static func trimToSpeech(
    fileURL: URL,
    firstWordStart: Float,
    lastWordEnd: Float,
  ) -> TrimResult? {
    guard firstWordStart < lastWordEnd else {
      return nil
    }

    let sourceFile: AVAudioFile
    do {
      sourceFile = try AVAudioFile(forReading: fileURL)
    } catch {
      return nil
    }

    guard
      let buffer = readTrimmedBuffer(
        from: sourceFile,
        firstWordStart: firstWordStart,
        lastWordEnd: lastWordEnd,
      )
    else {
      return nil
    }

    self.applyFades(buffer: buffer)

    guard self.writeAndReplace(buffer: buffer, sourceFile: sourceFile, fileURL: fileURL) else {
      return nil
    }

    let sampleRate = sourceFile.processingFormat.sampleRate
    let duration = Double(buffer.frameLength) / sampleRate
    let waveform = self.computeWaveform(buffer: buffer)

    return TrimResult(duration: duration, waveformSamples: waveform)
  }

  // MARK: Private

  private static let paddingSeconds: Float = 0.3
  private static let fadeFrameCount = 441 // ~10ms at 44.1kHz
  private static let skipThreshold = 0.95
  private static let waveformBinCount = 128

  private static func readTrimmedBuffer(
    from sourceFile: AVAudioFile,
    firstWordStart: Float,
    lastWordEnd: Float,
  ) -> AVAudioPCMBuffer? {
    let sampleRate = Float(sourceFile.processingFormat.sampleRate)
    let totalFrames = sourceFile.length
    let fileDuration = Float(totalFrames) / sampleRate

    let clampedStart = max(firstWordStart - self.paddingSeconds, 0)
    let clampedEnd = min(lastWordEnd + self.paddingSeconds, fileDuration)

    let startFrame = AVAudioFramePosition(clampedStart * sampleRate)
    let endFrame = min(AVAudioFramePosition(clampedEnd * sampleRate), totalFrames)
    let frameCount = AVAudioFrameCount(max(endFrame - startFrame, 0))

    guard frameCount > 0 else {
      return nil
    }

    let ratio = Double(frameCount) / Double(totalFrames)
    if ratio > Double(self.skipThreshold) {
      return nil
    }

    guard
      let format = AVAudioFormat(
        commonFormat: sourceFile.processingFormat.commonFormat,
        sampleRate: sourceFile.processingFormat.sampleRate,
        channels: sourceFile.processingFormat.channelCount,
        interleaved: sourceFile.processingFormat.isInterleaved,
      )
    else {
      return nil
    }

    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
      return nil
    }

    do {
      sourceFile.framePosition = startFrame
      try sourceFile.read(into: buffer, frameCount: frameCount)
    } catch {
      return nil
    }

    return buffer
  }

  private static func writeAndReplace(
    buffer: AVAudioPCMBuffer,
    sourceFile: AVAudioFile,
    fileURL: URL,
  ) -> Bool {
    let tempURL = fileURL.deletingLastPathComponent()
      .appendingPathComponent(UUID().uuidString + ".caf")

    do {
      let outputFile = try AVAudioFile(
        forWriting: tempURL,
        settings: sourceFile.fileFormat.settings,
      )
      try outputFile.write(from: buffer)
      try FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUnlessOpen],
        ofItemAtPath: tempURL.path,
      )
    } catch {
      try? FileManager.default.removeItem(at: tempURL)
      return false
    }

    do {
      _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
    } catch {
      try? FileManager.default.removeItem(at: tempURL)
      return false
    }

    return true
  }

  private static func applyFades(buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData else { return }
    let frameCount = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)

    let fadeIn = min(fadeFrameCount, frameCount / 2)
    let fadeOut = min(fadeFrameCount, frameCount / 2)

    for ch in 0..<channelCount {
      let ptr = channelData[ch]

      if fadeIn > 0 {
        var start: Float = 0
        var end: Float = 1
        var ramp = [Float](repeating: 0, count: fadeIn)
        vDSP_vgen(&start, &end, &ramp, 1, vDSP_Length(fadeIn))
        vDSP_vmul(ptr, 1, ramp, 1, ptr, 1, vDSP_Length(fadeIn))
      }

      if fadeOut > 0 {
        var start: Float = 1
        var end: Float = 0
        var ramp = [Float](repeating: 0, count: fadeOut)
        vDSP_vgen(&start, &end, &ramp, 1, vDSP_Length(fadeOut))
        let outStart = frameCount - fadeOut
        vDSP_vmul(ptr + outStart, 1, ramp, 1, ptr + outStart, 1, vDSP_Length(fadeOut))
      }
    }
  }

  /// Computes waveform using DSWaveformImage convention (0 = loud, 1 = silent).
  private static func computeWaveform(buffer: AVAudioPCMBuffer) -> [Float] {
    guard let channelData = buffer.floatChannelData else {
      return Array(repeating: Float(1), count: self.waveformBinCount)
    }

    let frameCount = Int(buffer.frameLength)
    guard frameCount > 0 else {
      return Array(repeating: Float(1), count: self.waveformBinCount)
    }

    let ptr = channelData[0]
    let binSize = Float(frameCount) / Float(self.waveformBinCount)
    var result = [Float](repeating: 1, count: waveformBinCount)

    for bin in 0..<self.waveformBinCount {
      let start = Int(Float(bin) * binSize)
      let end = min(Int(Float(bin + 1) * binSize), frameCount)
      guard start < end else { continue }

      var maxVal: Float = 0
      vDSP_maxmgv(ptr + start, 1, &maxVal, vDSP_Length(end - start))
      result[bin] = 1 - min(maxVal, 1)
    }

    return result
  }
}
