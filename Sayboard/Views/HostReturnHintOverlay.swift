import SwiftUI
import UIKit

struct HostReturnHintOverlay: View {

  let onClose: () -> Void

  var body: some View {
    ZStack {
      self.opaqueBackground
        .ignoresSafeArea()

      self.messageCard
      self.closeButtonOverlay
      self.bottomBarHint
    }
  }

  private static let cardInnerSpacing: CGFloat = 8
  private static let horizontalPadding: CGFloat = 32
  private static let maxContentWidth: CGFloat = 420
  private static let closeHitSize: CGFloat = 44
  private static let closeBackdropSize: CGFloat = 32
  private static let closeBackdropOpacity = 0.3
  private static let closePadding: CGFloat = 8

  @Environment(\.colorScheme) private var colorScheme

  private var opaqueBackground: Color {
    let style: UIUserInterfaceStyle = self.colorScheme == .dark ? .dark : .light
    let traits = UITraitCollection { mutableTraits in
      mutableTraits.userInterfaceStyle = style
      mutableTraits.userInterfaceLevel = .elevated
    }
    return Color(UIColor.systemGroupedBackground.resolvedColor(with: traits))
  }

  private var messageCard: some View {
    VStack(spacing: Self.cardInnerSpacing) {
      Text("Swipe right to return")
        .font(.title2.bold())
        .multilineTextAlignment(.center)
      Text(
        "The app opened to turn on the microphone: no mic session was active. Recording is already running — just head back."
      )
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
    }
    .padding(.horizontal, Self.horizontalPadding)
    .frame(maxWidth: Self.maxContentWidth)
  }

  private var bottomBarHint: some View {
    VStack(spacing: Self.cardInnerSpacing) {
      Spacer()
      SwipeRightAnimation()
        .accessibilityHidden(true)
      Text("Swipe right on the indicator below")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Image(systemName: "arrow.down")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
    }
  }

  private var closeButtonOverlay: some View {
    VStack {
      HStack {
        Spacer()
        Button(action: self.onClose) {
          Image(systemName: "xmark")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: Self.closeBackdropSize, height: Self.closeBackdropSize)
            .background(Circle().fill(Color.primary.opacity(Self.closeBackdropOpacity)))
            .frame(width: Self.closeHitSize, height: Self.closeHitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Dismiss"))
      }
      Spacer()
    }
    .padding(Self.closePadding)
  }

}

private struct SwipeRightAnimation: View {

  var body: some View {
    TimelineView(.animation) { context in
      let absoluteSeconds = context.date.timeIntervalSinceReferenceDate
      let progress = absoluteSeconds.truncatingRemainder(dividingBy: Self.cycleDuration) / Self.cycleDuration
      let eased = Self.easeInOut(progress)

      ZStack {
        Capsule()
          .fill(Color.primary.opacity(Self.barOpacity))
          .frame(width: Self.barWidth, height: Self.barHeight)

        Circle()
          .fill(Color.primary.opacity(Self.cursorOpacity))
          .frame(width: Self.cursorSize, height: Self.cursorSize)
          .shadow(color: Color.primary.opacity(Self.cursorShadowOpacity), radius: 4)
          .offset(x: Self.cursorOffsetX(progress: eased))
          .opacity(Self.cursorTrackOpacity(progress: progress))
      }
      .frame(
        width: Self.barWidth + Self.cursorSize,
        height: Self.cursorSize + Self.barHeight,
      )
    }
  }

  private static let barWidth: CGFloat = 120
  private static let barHeight: CGFloat = 5
  private static let barOpacity = 0.18
  private static let cursorSize: CGFloat = 28
  private static let cursorOpacity = 0.25
  private static let cursorShadowOpacity = 0.1
  private static let cycleDuration: TimeInterval = 1.8
  private static let fadeInThreshold = 0.12
  private static let fadeOutThreshold = 0.85

  private static func cursorOffsetX(progress: Double) -> CGFloat {
    -Self.barWidth / 2 + CGFloat(progress) * Self.barWidth
  }

  private static func cursorTrackOpacity(progress: Double) -> Double {
    if progress < Self.fadeInThreshold {
      return progress / Self.fadeInThreshold
    }
    if progress > Self.fadeOutThreshold {
      return max(0, 1 - (progress - Self.fadeOutThreshold) / (1 - Self.fadeOutThreshold))
    }
    return 1
  }

  private static func easeInOut(_ x: Double) -> Double {
    -(cos(.pi * x) - 1) / 2
  }
}

#Preview {
  HostReturnHintOverlay { }
}
