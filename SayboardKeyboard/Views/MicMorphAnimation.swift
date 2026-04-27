// MicMorphAnimation -- Plays the 16-frame mic-to-wave morph (or reverse)

import SwiftUI

// MARK: - MicMorphAnimation

struct MicMorphAnimation: View {

  // MARK: Internal

  enum Direction {
    case toWave
    case toMic
  }

  var direction: Direction
  var onComplete: () -> Void

  var body: some View {
    TimelineView(.animation(minimumInterval: Self.frameDuration, paused: self.isComplete)) { timeline in
      let index = self.frameIndex(at: timeline.date)
      MicMorphShape(frameIndex: index)
        .fill(.primary)
        .onChange(of: index) { _, newIndex in
          let target = self.direction == .toWave ? Self.lastFrame : 0
          if newIndex == target {
            self.isComplete = true
            self.onComplete()
          }
        }
    }
    .onAppear {
      self.startTime = Date()
    }
  }

  // MARK: Private

  private static let frameDuration: TimeInterval = 0.18 / 16
  private static let lastFrame = MicMorphFrames.frameCount - 1

  @State private var startTime: Date?
  @State private var isComplete = false

  private func frameIndex(at date: Date) -> Int {
    guard let start = self.startTime else {
      return self.direction == .toWave ? 0 : Self.lastFrame
    }
    let elapsed = date.timeIntervalSince(start)
    let rawFrame = Int(elapsed / Self.frameDuration)
    let clamped = min(rawFrame, Self.lastFrame)
    return self.direction == .toWave ? clamped : Self.lastFrame - clamped
  }
}
