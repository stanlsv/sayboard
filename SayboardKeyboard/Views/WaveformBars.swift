import SwiftUI

// WaveformBars -- Animated vertical bars driven by audio level (0...1).
// Single shared sine with progressive phase offset per bar — peak visibly
// travels across the bars (rope-flick effect). TimelineView at 60 fps; pauses
// automatically when level drops to zero (idle).

// MARK: - WaveformBars

struct WaveformBars: View {

  // MARK: Internal

  var level: Float
  var scale: CGFloat = 1.0

  var body: some View {
    let boosted = CGFloat(sqrt(self.level))
    let isActive = boosted > 0.01

    TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !isActive)) { timeline in
      let time = timeline.date.timeIntervalSinceReferenceDate

      HStack(spacing: self.barSpacing) {
        ForEach(0..<self.barCount, id: \.self) { index in
          let height = self.barHeight(for: index, time: time, boosted: boosted)
          RoundedRectangle(cornerRadius: self.barWidth / 2, style: .continuous)
            .fill(.primary)
            .frame(width: self.barWidth, height: height)
        }
      }
      .frame(height: self.maxBarHeight)
    }
  }

  // MARK: Private

  private let barCount = 5
  private let heightMultipliers: [CGFloat] = [0.6, 0.8, 1.0, 0.8, 0.6]
  private let omega = 7.8
  private let phaseOffset: Double = .pi / 2

  private var barWidth: CGFloat {
    4.kbScaled * self.scale
  }

  private var barSpacing: CGFloat {
    4.kbScaled * self.scale
  }

  private var minBarHeight: CGFloat {
    4.kbScaled * self.scale
  }

  private var maxBarHeight: CGFloat {
    30.kbScaled * self.scale
  }

  private func barHeight(for index: Int, time: Double, boosted: CGFloat) -> CGFloat {
    guard boosted > 0.01 else { return self.minBarHeight }

    let phase = time * self.omega - Double(index) * self.phaseOffset
    let wave = CGFloat(0.5 + 0.5 * sin(phase)) // 0...1

    let amplitude = boosted * self.heightMultipliers[index] * wave
    let height = self.minBarHeight + amplitude * (self.maxBarHeight - self.minBarHeight)
    return max(self.minBarHeight, min(self.maxBarHeight, height))
  }
}
