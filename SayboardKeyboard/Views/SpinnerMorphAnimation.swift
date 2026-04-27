// SpinnerMorphAnimation -- Plays the 15-frame spinner-to-mic morph

import SwiftUI

// MARK: - SpinnerMorphAnimation

struct SpinnerMorphAnimation: View {

  // MARK: Internal

  var canStep: Bool
  var onComplete: () -> Void

  var body: some View {
    TimelineView(
      .animation(minimumInterval: Self.frameDuration, paused: !self.canStep || self.isComplete)
    ) { timeline in
      let index = self.frameIndex(at: timeline.date)
      SpinnerMorphShape(frameIndex: index)
        .fill(.primary)
        .onChange(of: index) { _, newIndex in
          if newIndex == Self.lastFrame {
            self.isComplete = true
            self.onComplete()
          }
        }
    }
    .onAppear {
      if self.canStep {
        self.startTime = Date()
      }
    }
    .onChange(of: self.canStep) { _, canStep in
      if canStep {
        self.startTime = Date()
      }
    }
  }

  // MARK: Private

  private static let frameDuration: TimeInterval = 0.18 / 15
  private static let lastFrame = SpinnerMorphFrames.frameCount - 1

  @State private var startTime: Date?
  @State private var isComplete = false

  private func frameIndex(at date: Date) -> Int {
    guard let start = self.startTime else { return 0 }
    let elapsed = date.timeIntervalSince(start)
    let rawFrame = Int(elapsed / Self.frameDuration)
    return min(rawFrame, Self.lastFrame)
  }
}
