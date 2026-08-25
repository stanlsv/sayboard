
import os

final class AudioBufferAccumulator: Sendable {

  var samples: [Float] {
    self.buffer.withLock { Array($0) }
  }

  func append(_ newSamples: [Float]) {
    self.buffer.withLock { $0.append(contentsOf: newSamples) }
  }

  func reset() {
    self.buffer.withLock { $0.removeAll(keepingCapacity: true) }
  }

  private let buffer = OSAllocatedUnfairLock<ContiguousArray<Float>>(initialState: [])
}
