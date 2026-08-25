
import Accelerate
@preconcurrency import AVFoundation
import os

enum AudioBufferMath {

  static let targetSampleRate: Double = 16_000

  static let rmsPreFilterWindowSize = 4

  static func resample(
    _ buffer: AVAudioPCMBuffer,
    converter: AVAudioConverter,
    targetFormat: AVAudioFormat,
    diagnostics: OSAllocatedUnfairLock<TapDiagnostics>,
  ) -> [Float] {
    let frameCount = AVAudioFrameCount(
      Double(buffer.frameLength) * self.targetSampleRate / buffer.format.sampleRate
    )
    guard
      let convertedBuffer = AVAudioPCMBuffer(
        pcmFormat: targetFormat,
        frameCapacity: frameCount + 1,
      )
    else {
      diagnostics.withLock { $0.allocFailures += 1 }
      return []
    }

    let gotData = OSAllocatedUnfairLock(initialState: false)
    let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
      let alreadyProvided = gotData.withLock { current -> Bool in
        if current { return true }
        current = true
        return false
      }
      if alreadyProvided {
        outStatus.pointee = .noDataNow
        return nil
      }
      outStatus.pointee = .haveData
      return buffer
    }

    var error: NSError?
    converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
    if let error {
      diagnostics.withLock {
        $0.convertErrors += 1
        $0.lastConvertErrorCode = error.code
      }
      return []
    }
    guard convertedBuffer.frameLength > 0 else {
      diagnostics.withLock { $0.emptyConversions += 1 }
      return []
    }
    guard let channelData = convertedBuffer.floatChannelData else {
      diagnostics.withLock { $0.missingChannelData += 1 }
      return []
    }
    return Array(UnsafeBufferPointer(start: channelData[0], count: Int(convertedBuffer.frameLength)))
  }

  static func preFilterRMS(
    _ rms: Float,
    ringBuffer: OSAllocatedUnfairLock<(buffer: [Float], index: Int)>,
  ) -> Float {
    ringBuffer.withLock { state -> Float in
      state.buffer[state.index % state.buffer.count] = rms
      state.index += 1
      var mean: Float = 0
      vDSP_meanv(state.buffer, 1, &mean, vDSP_Length(state.buffer.count))
      return mean
    }
  }

  static func smoothLevel(
    _ scaled: Float,
    previous: OSAllocatedUnfairLock<Float>,
  ) -> Float {
    previous.withLock { prev -> Float in
      let alpha: Float = scaled > prev ? 0.7 : 0.5
      let result = alpha * scaled + (1 - alpha) * prev
      prev = result
      return result
    }
  }

  static func rms(from buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData else { return 0 }
    var value: Float = 0
    vDSP_rmsqv(channelData[0], 1, &value, vDSP_Length(buffer.frameLength))
    return value
  }

  static func samples(from buffer: AVAudioPCMBuffer) -> [Float] {
    guard let channelData = buffer.floatChannelData else { return [] }
    return Array(UnsafeBufferPointer(start: channelData[0], count: Int(buffer.frameLength)))
  }
}
