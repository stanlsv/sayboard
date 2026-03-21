// KeyboardAnimations -- WavyCircle, PulseRings, and MetaballSpinner used in keyboard view

import SwiftUI

// MARK: - WavyCircle

struct WavyCircle: Shape {
  var phase: Double
  var waveAmplitude: CGFloat = 2.5
  var waveFrequency: Double = 4
  var secondaryAmplitude: CGFloat = 1.5
  var secondaryFrequency: Double = 6

  var animatableData: Double {
    get { self.phase }
    set { self.phase = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let baseRadius = min(rect.width, rect.height) / 2
    let steps = 120

    var path = Path()
    for i in 0...steps {
      let angle = Double(i) / Double(steps) * 2 * .pi
      let offset = self.waveAmplitude * sin(self.waveFrequency * angle + self.phase)
        + self.secondaryAmplitude * sin(self.secondaryFrequency * angle - self.phase * 2)
      let radius = baseRadius + CGFloat(offset)
      let point = CGPoint(
        x: center.x + cos(angle) * radius,
        y: center.y + sin(angle) * radius,
      )
      if i == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
    }
    path.closeSubpath()
    return path
  }
}

// MARK: - PulseRings

struct PulseRings: View {

  // MARK: Internal

  /// Maximum visual diameter including WavyCircle distortion.
  /// Outer ring frame: buttonDiameter + ringCount * ringSpacing = 154
  /// Wave overflow: ±(waveAmplitude 2.5 + secondaryAmplitude 1.5) = ±4pt → +8
  static let maxDiameter: CGFloat = buttonDiameter + CGFloat(ringCount) * ringSpacing + 8

  var body: some View {
    ZStack {
      ForEach(0..<Self.ringCount, id: \.self) { index in
        let diameter = Self.buttonDiameter + CGFloat(index + 1) * Self.ringSpacing
        WavyCircle(phase: self.wavePhase + Double(index) * .pi)
          .fill(Color(.keyBackground))
          .opacity(self.isAnimating ? Self.maxOpacity : Self.minOpacity)
          .frame(width: diameter, height: diameter)
          .scaleEffect(self.isAnimating ? 1 : Self.minScale)
      }
    }
    .allowsHitTesting(false)
    .animation(
      .easeInOut(duration: Self.pulseDuration).repeatForever(autoreverses: true),
      value: self.isAnimating,
    )
    .onAppear {
      self.isAnimating = true
      withAnimation(.linear(duration: Self.waveDuration).repeatForever(autoreverses: false)) {
        self.wavePhase = 2 * .pi
      }
    }
  }

  // MARK: Private

  private static let buttonDiameter: CGFloat = 106
  private static let ringSpacing: CGFloat = 24
  private static let ringCount = 2

  private static let minOpacity = 0.15
  private static let maxOpacity = 0.35
  private static let minScale = 0.9
  private static let pulseDuration = 1.0
  private static let waveDuration = 6.0

  @State private var isAnimating = false
  @State private var wavePhase = 0.0

}

// MARK: - MetaballSpinner

/// Two circles orbiting each other — processing indicator.
struct MetaballSpinner: View {

  // MARK: Internal

  let color: Color
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(self.color)
        .frame(width: self.dotDiameter, height: self.dotDiameter)
        .offset(x: -self.spread + self.oscillationRange * self.phase)

      Circle()
        .fill(self.color)
        .frame(width: self.dotDiameter, height: self.dotDiameter)
        .offset(x: self.spread - self.oscillationRange * self.phase)
    }
    .rotationEffect(.degrees(self.rotation))
    .frame(width: self.size, height: self.size)
    .onAppear {
      withAnimation(.linear(duration: Self.rotationPeriod).repeatForever(autoreverses: false)) {
        self.rotation = 360
      }
      withAnimation(.easeInOut(duration: Self.oscillationPeriod).repeatForever(autoreverses: true)) {
        self.phase = 1
      }
    }
  }

  // MARK: Private

  // Proportions derived from SVG: 24x24 viewBox, r=4 circles at cx=5/19
  private static let rotationPeriod = 0.88
  private static let oscillationPeriod = 1.8

  @State private var rotation = 0.0
  @State private var phase = 0.0

  private var dotDiameter: CGFloat {
    self.size * 0.333
  }

  private var spread: CGFloat {
    self.size * 0.36
  }

  private var oscillationRange: CGFloat {
    self.size * 0.15
  }

}
