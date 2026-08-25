
import Foundation

struct TapDiagnostics: Sendable {
  var buffers = 0
  var inputFrames = 0
  var outputFrames = 0
  var allocFailures = 0
  var convertErrors = 0
  var emptyConversions = 0
  var missingChannelData = 0
  var lastConvertErrorCode = 0
  var inputSampleRate: Double = 0
  var inputChannels: UInt32 = 0
  var peakRMS: Float = 0
}

extension BackgroundAudioSession {

  func logTapDiagnostics() {
    let diag = self.tapDiagnostics.withLock { current -> TapDiagnostics in
      let value = current
      current = TapDiagnostics()
      return value
    }
    guard diag.buffers > 0 else {
      DiagnosticLog.write("tap: NO BUFFERS delivered while tap was active")
      return
    }
    DiagnosticLog.write(
      "tap: buffers=\(diag.buffers) inFrames=\(diag.inputFrames) outFrames=\(diag.outputFrames) "
        + "tapFormat=\(diag.inputSampleRate)Hz/\(diag.inputChannels)ch peakRMS=\(diag.peakRMS)"
    )
    DiagnosticLog.write(
      "tap: allocFail=\(diag.allocFailures) convertErr=\(diag.convertErrors) errCode=\(diag.lastConvertErrorCode) "
        + "emptyConv=\(diag.emptyConversions) noChannelData=\(diag.missingChannelData)"
    )
  }
}
