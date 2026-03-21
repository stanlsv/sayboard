import DSWaveformImage
import DSWaveformImageViews
import SwiftUI

// WaveformPlayerView -- Voice-message-style audio player with waveform visualization

struct WaveformPlayerView: View {

  // MARK: Internal

  let audioURL: URL
  let totalDuration: TimeInterval
  let waveformSamples: [Float]

  @ObservedObject var playerService: AudioPlayerService

  var body: some View {
    HStack(spacing: self.hStackSpacing) {
      self.playButton
      self.currentTimeLabel
      self.waveformArea
      self.durationLabel
    }
    .padding(.horizontal, self.horizontalPadding)
    .padding(.vertical, self.verticalPadding)
    .background { self.bubbleBackground }
  }

  // MARK: Private

  @State private var wasPlayingBeforeScrub = false

  private let scrubberDotSize: CGFloat = 6
  private let scrubberLineWidth: CGFloat = 1.5
  private let waveformHeight: CGFloat = 28
  private let verticalPadding: CGFloat = 10

  private let horizontalPadding: CGFloat = 12
  private let playButtonSize: CGFloat = 24
  private let timeLabelWidth: CGFloat = 28
  private let hStackSpacing: CGFloat = 10

  private let stripeWidth: CGFloat = 2
  private let stripeSpacing: CGFloat = 2

  private var isActive: Bool {
    self.playerService.currentFileURL == self.audioURL
  }

  private var progress: Double {
    guard self.isActive, self.playerService.duration > 0 else { return 0 }
    return self.playerService.currentTime / self.playerService.duration
  }

  private var isPlaying: Bool {
    self.isActive && self.playerService.isPlaying
  }

  private var playButton: some View {
    let extraTapInset: CGFloat = 10
    return Button {
      self.playerService.togglePlayback(url: self.audioURL)
    } label: {
      PlayPauseShape(progress: self.isPlaying ? 1 : 0)
        .fill(self.isActive ? Color.blue : Color.secondary)
        .frame(width: 14, height: 16)
        .scaleEffect(self.isPlaying ? 1.0 : 1.08)
        .frame(width: self.playButtonSize, height: self.playButtonSize)
        .animation(.easeInOut(duration: 0.1), value: self.isPlaying)
        .padding(extraTapInset)
        .contentShape(Rectangle())
        .padding(-extraTapInset)
    }
    .buttonStyle(.plain)
  }

  private var currentTimeLabel: some View {
    let time = self.isActive ? self.playerService.currentTime : 0
    return Text(self.formatTime(time))
      .font(.caption2)
      .monospacedDigit()
      .foregroundStyle(self.isActive ? .blue : .secondary)
      .frame(width: self.timeLabelWidth, alignment: .trailing)
  }

  private var waveformArea: some View {
    GeometryReader { geometry in
      self.waveformLayers(size: geometry.size)
        .overlay {
          HorizontalPanGestureView(
            onPanBegan: {
              self.wasPlayingBeforeScrub = self.isPlaying
              if self.isPlaying { self.playerService.pause() }
            },
            onChanged: { x in
              self.scrubToPosition(x, in: geometry.size.width)
            },
            onEnded: {
              if self.wasPlayingBeforeScrub {
                self.playerService.play(url: self.audioURL)
              }
              self.wasPlayingBeforeScrub = false
            },
            onTap: { x in
              self.seekToPosition(x, in: geometry.size.width)
            },
          )
        }
    }
    .frame(height: self.waveformHeight)
  }

  private var durationLabel: some View {
    Text(self.formatTime(self.totalDuration))
      .font(.caption2)
      .monospacedDigit()
      .foregroundStyle(.secondary)
      .frame(width: self.timeLabelWidth, alignment: .leading)
  }

  private var bubbleBackground: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Color(.systemGray6)
        if self.isActive, self.progress > 0 {
          Color.blue.opacity(0.12)
            .frame(width: self.blueFillWidth(bubbleWidth: geo.size.width))
        }
      }
      .clipShape(.rect(cornerRadius: 16))
    }
  }

  private func waveformLayers(size: CGSize) -> some View {
    let displaySamples = self.resampledForDisplay(width: size.width)
    let config = self.waveformConfiguration(color: .gray)
    return ZStack(alignment: .leading) {
      self.styledWaveform(samples: displaySamples, configuration: config, color: .gray.opacity(0.35))
      self.styledWaveform(samples: displaySamples, configuration: config, color: .blue)
        .mask(alignment: .leading) {
          Rectangle()
            .frame(width: size.width * self.progress)
        }
      if self.isActive, self.progress > 0 {
        let bubbleHeight = size.height + self.verticalPadding * 2
        self.scrubber(lineHeight: bubbleHeight)
          .position(x: size.width * self.progress, y: size.height / 2)
      }
    }
  }

  private func styledWaveform(
    samples: [Float],
    configuration: Waveform.Configuration,
    color: Color,
  ) -> some View {
    WaveformShape(samples: samples, configuration: configuration)
      .stroke(color, style: StrokeStyle(lineWidth: self.stripeWidth, lineCap: .round))
  }

  private func resampledForDisplay(width: CGFloat) -> [Float] {
    let scale = UIScreen.main.scale
    let targetCount = Int(width * scale)
    guard targetCount > 0 else { return [] }

    guard !self.waveformSamples.isEmpty else {
      return Array(repeating: Float(1), count: targetCount)
    }

    let source = self.waveformSamples
    guard source.count > 1 else {
      return Array(repeating: source[0], count: targetCount)
    }

    var result = [Float](repeating: 0, count: targetCount)
    let sourceLastIndex = Float(source.count - 1)
    let targetLastIndex = Float(targetCount - 1)

    for i in 0..<targetCount {
      let srcPos = Float(i) * sourceLastIndex / targetLastIndex
      let lower = Int(srcPos)
      let upper = min(lower + 1, source.count - 1)
      let fraction = srcPos - Float(lower)
      result[i] = source[lower] + fraction * (source[upper] - source[lower])
    }

    return result
  }

  private func scrubber(lineHeight: CGFloat) -> some View {
    Rectangle()
      .frame(width: self.scrubberLineWidth, height: lineHeight)
      .overlay(alignment: .top) {
        Circle()
          .frame(width: self.scrubberDotSize, height: self.scrubberDotSize)
          .offset(y: -self.scrubberDotSize * 0.8)
      }
      .overlay(alignment: .bottom) {
        Circle()
          .frame(width: self.scrubberDotSize, height: self.scrubberDotSize)
          .offset(y: self.scrubberDotSize * 0.8)
      }
      .foregroundStyle(.blue)
  }

  private func blueFillWidth(bubbleWidth: CGFloat) -> CGFloat {
    let waveformLeadingX = self.horizontalPadding + self.playButtonSize + self.hStackSpacing + self.timeLabelWidth + self
      .hStackSpacing
    let fixedWidth = self.horizontalPadding * 2 + self.playButtonSize + self.timeLabelWidth * 2 + self.hStackSpacing * 3
    let waveformWidth = max(bubbleWidth - fixedWidth, 0)
    return waveformLeadingX + waveformWidth * self.progress
  }

  private func waveformConfiguration(color: Color) -> Waveform.Configuration {
    Waveform.Configuration(
      style: .striped(
        .init(color: UIColor(color), width: self.stripeWidth, spacing: self.stripeSpacing, lineCap: .round)
      ),
      damping: .init(percentage: 0.1, sides: .both),
      verticalScalingFactor: 0.45,
    )
  }

  private func scrubToPosition(_ x: CGFloat, in width: CGFloat) {
    guard width > 0 else { return }
    if !self.isActive {
      self.playerService.play(url: self.audioURL)
      self.playerService.pause()
    }
    guard self.playerService.duration > 0 else { return }
    let minFraction = 1 / width
    let fraction = min(max(x / width, minFraction), 1)
    self.playerService.seek(to: fraction * self.playerService.duration)
  }

  private func seekToPosition(_ x: CGFloat, in width: CGFloat) {
    self.scrubToPosition(x, in: width)
  }

  private func formatTime(_ time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}
