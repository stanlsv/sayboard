
import SwiftUI

struct MicHintArrow: View {

  nonisolated static let gap: CGFloat = 10

  var body: some View {
    Image(systemName: "arrow.right")
      .font(.system(size: Self.size.kbScaled, weight: .bold))
      .foregroundStyle(Self.color)
      .keyframeAnimator(initialValue: -Self.travel.kbScaled, repeating: true) { arrow, offset in
        arrow.offset(x: offset)
      } keyframes: { _ in
        CubicKeyframe(0, duration: Self.halfCycle)
        CubicKeyframe(-Self.travel.kbScaled, duration: Self.halfCycle)
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
  }

  private static let size: CGFloat = 24
  private static let travel: CGFloat = 8
  private static let halfCycle = 0.6

  private static let color = Color(.sRGB, red: 0.188, green: 0.478, blue: 0.988)
}
