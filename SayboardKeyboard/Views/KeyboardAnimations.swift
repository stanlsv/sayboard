
import SwiftUI

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

struct WavyRoundedRectangle: Shape {

  var phase: Double
  var cornerRadius: CGFloat
  var waveAmplitude: CGFloat = 2.5
  var waveFrequency: Double = 4
  var secondaryAmplitude: CGFloat = 1.5
  var secondaryFrequency: Double = 6

  var animatableData: Double {
    get { self.phase }
    set { self.phase = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let steps = 240
    let metrics = Metrics(rect: rect, cornerRadius: self.cornerRadius)
    var path = Path()
    for i in 0...steps {
      let progress = Double(i) / Double(steps)
      let (base, normal) = self.outline(at: CGFloat(progress) * metrics.perimeter, rect: rect, metrics: metrics)
      let angle = progress * 2 * .pi
      let offset = self.waveAmplitude * sin(self.waveFrequency * angle + self.phase)
        + self.secondaryAmplitude * sin(self.secondaryFrequency * angle - self.phase * 2)
      let point = CGPoint(x: base.x + normal.dx * offset, y: base.y + normal.dy * offset)
      if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
  }

  private struct Metrics {
    init(rect: CGRect, cornerRadius: CGFloat) {
      let radius = max(0, min(cornerRadius, min(rect.width, rect.height) / 2))
      let edgeH = rect.width - 2 * radius
      let edgeV = rect.height - 2 * radius
      let arc = (.pi / 2) * radius
      self.radius = radius
      self.edgeH = edgeH
      self.edgeV = edgeV
      self.arc = arc
      self.perimeter = 2 * edgeH + 2 * edgeV + 4 * arc
    }

    let radius: CGFloat
    let edgeH: CGFloat
    let edgeV: CGFloat
    let arc: CGFloat
    let perimeter: CGFloat

  }

  private static func corner(startAngle: Double, distance: CGFloat, radius: CGFloat, center: CGPoint) -> (CGPoint, CGVector) {
    let angle = startAngle + Double(distance / max(radius, 0.0001))
    let normal = CGVector(dx: cos(angle), dy: sin(angle))
    return (CGPoint(x: center.x + normal.dx * radius, y: center.y + normal.dy * radius), normal)
  }

  private func outline(at arcLength: CGFloat, rect: CGRect, metrics: Metrics) -> (CGPoint, CGVector) {
    let radius = metrics.radius
    let topRight = CGPoint(x: rect.maxX - radius, y: rect.minY + radius)
    let bottomRight = CGPoint(x: rect.maxX - radius, y: rect.maxY - radius)
    let bottomLeft = CGPoint(x: rect.minX + radius, y: rect.maxY - radius)
    let topLeft = CGPoint(x: rect.minX + radius, y: rect.minY + radius)
    var distance = arcLength
    if distance <= metrics.edgeH {
      return (CGPoint(x: rect.minX + radius + distance, y: rect.minY), CGVector(dx: 0, dy: -1))
    }
    distance -= metrics.edgeH
    if distance <= metrics.arc {
      return Self.corner(startAngle: -.pi / 2, distance: distance, radius: radius, center: topRight)
    }
    distance -= metrics.arc
    if distance <= metrics.edgeV {
      return (CGPoint(x: rect.maxX, y: rect.minY + radius + distance), CGVector(dx: 1, dy: 0))
    }
    distance -= metrics.edgeV
    if distance <= metrics.arc {
      return Self.corner(startAngle: 0, distance: distance, radius: radius, center: bottomRight)
    }
    distance -= metrics.arc
    if distance <= metrics.edgeH {
      return (CGPoint(x: rect.maxX - radius - distance, y: rect.maxY), CGVector(dx: 0, dy: 1))
    }
    distance -= metrics.edgeH
    if distance <= metrics.arc {
      return Self.corner(startAngle: .pi / 2, distance: distance, radius: radius, center: bottomLeft)
    }
    distance -= metrics.arc
    if distance <= metrics.edgeV {
      return (CGPoint(x: rect.minX, y: rect.maxY - radius - distance), CGVector(dx: -1, dy: 0))
    }
    distance -= metrics.edgeV
    return Self.corner(startAngle: .pi, distance: distance, radius: radius, center: topLeft)
  }

}

struct PulseRings: View {

  let buttonWidth: CGFloat
  let buttonHeight: CGFloat
  let cornerRadius: CGFloat
  let ringSpacing: CGFloat

  var maxWidth: CGFloat {
    let ringExtent = CGFloat(Self.ringCount) * self.ringSpacing
    let waveOverflow: CGFloat = 8.kbScaled
    return self.buttonWidth + ringExtent + waveOverflow
  }

  var maxHeight: CGFloat {
    let ringExtent = CGFloat(Self.ringCount) * self.ringSpacing
    let waveOverflow: CGFloat = 8.kbScaled
    return self.buttonHeight + ringExtent + waveOverflow
  }

  var body: some View {
    let sizeRatio = self.buttonWidth / Self.referenceDiameter
    let waveAmplitude = Self.referenceWaveAmplitude * sizeRatio
    let secondaryAmplitude = Self.referenceSecondaryAmplitude * sizeRatio
    return ZStack {
      ForEach(0..<Self.ringCount, id: \.self) { index in
        self.ring(index: index, waveAmplitude: waveAmplitude, secondaryAmplitude: secondaryAmplitude)
          .opacity(self.isAnimating ? Self.maxOpacity : Self.minOpacity)
          .scaleEffect(self.isAnimating ? 1 : Self.minScale)
      }
    }
    .frame(width: self.maxWidth, height: self.maxHeight)
    .compositingGroup()
    .mask {
      ZStack {
        Rectangle().fill(.black)
        self.cutout()
      }
      .compositingGroup()
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

  private static let ringCount = 2
  private static let minOpacity = 0.15
  private static let maxOpacity = 0.35
  private static let minScale = 0.9
  private static let pulseDuration = 1.0
  private static let waveDuration = 6.0
  private static let referenceDiameter: CGFloat = 106
  private static let referenceWaveAmplitude: CGFloat = 2.5
  private static let referenceSecondaryAmplitude: CGFloat = 1.5

  @State private var isAnimating = false
  @State private var wavePhase = 0.0

  private var isCircle: Bool {
    abs(self.buttonWidth - self.buttonHeight) < 0.5 && self.cornerRadius >= self.buttonHeight / 2 - 0.5
  }

  @ViewBuilder
  private func ring(index: Int, waveAmplitude: CGFloat, secondaryAmplitude: CGFloat) -> some View {
    let grow = CGFloat(index + 1) * self.ringSpacing
    let fill = Color(.keyBackground)
    if self.isCircle {
      WavyCircle(
        phase: self.wavePhase + Double(index) * .pi,
        waveAmplitude: waveAmplitude,
        secondaryAmplitude: secondaryAmplitude,
      )
      .fill(fill)
      .frame(width: self.buttonWidth + grow, height: self.buttonHeight + grow)
    } else {
      WavyRoundedRectangle(
        phase: self.wavePhase + Double(index) * .pi,
        cornerRadius: self.cornerRadius + grow / 2,
        waveAmplitude: waveAmplitude,
        secondaryAmplitude: secondaryAmplitude,
      )
      .fill(fill)
      .frame(width: self.buttonWidth + grow, height: self.buttonHeight + grow)
    }
  }

  private func cutout() -> some View {
    Group {
      if self.isCircle {
        Circle()
      } else {
        RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous)
      }
    }
    .frame(width: self.buttonWidth, height: self.buttonHeight)
    .blendMode(.destinationOut)
  }

}

struct MetaballSpinner: View {

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
