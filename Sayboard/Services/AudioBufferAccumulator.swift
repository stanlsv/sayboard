// AudioBufferAccumulator -- Thread-safe accumulator for 16kHz mono audio samples

import os

final class AudioBufferAccumulator: Sendable {

  // MARK: Internal

  var samples: [Float] {
    self.buffer.withLock { Array($0) }
  }

  func append(_ newSamples: [Float]) {
    self.buffer.withLock { $0.append(contentsOf: newSamples) }
  }

  func reset() {
    self.buffer.withLock { $0.removeAll(keepingCapacity: true) }
  }

  // MARK: Private

  private let buffer = OSAllocatedUnfairLock<ContiguousArray<Float>>(initialState: [])
}
