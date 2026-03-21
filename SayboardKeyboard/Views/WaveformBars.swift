import SwiftUI

// WaveformBars -- Animated vertical bars driven by audio level (0...1).
// TimelineView drives continuous sine-wave sampling at ~30 fps while active;
// pauses automatically when level drops to zero (idle).

// MARK: - WaveformBars

struct WaveformBars: View {

  // MARK: Internal

  var level: Float

  var body: some View {
    let boosted = CGFloat(sqrt(self.level))
    let isActive = boosted > 0.01

    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isActive)) { timeline in
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
  private let barWidth: CGFloat = 4
  private let barSpacing: CGFloat = 4
  private let minBarHeight: CGFloat = 4
  private let maxBarHeight: CGFloat = 46
  private let heightMultipliers: [CGFloat] = [0.6, 0.8, 1.0, 0.8, 0.6]

  /// Each bar gets its own unique frequency pair -- no visible traveling-wave pattern.
  private let barFrequencies: [(Double, Double)] = [
    (7.2, 4.9),
    (8.7, 5.3),
    (9.5, 6.4),
    (8.1, 5.8),
    (7.6, 4.6),
  ]

  private func barHeight(for index: Int, time: Double, boosted: CGFloat) -> CGFloat {
    guard boosted > 0.01 else { return self.minBarHeight }

    let freqs = self.barFrequencies[index]
    let waveA = sin(time * freqs.0) * 0.6
    let waveB = sin(time * freqs.1) * 0.4
    let wave = CGFloat((waveA + waveB + 1.0) / 2.0) // normalized 0...1

    let amplitude = boosted * self.heightMultipliers[index]
    let height = self.minBarHeight + wave * (self.maxBarHeight - self.minBarHeight) * amplitude
    return max(self.minBarHeight, min(self.maxBarHeight, height))
  }
}
