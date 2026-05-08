import SwiftUI
import UIKit

// KeyCallout -- Apple-style input callout (popup balloon) over a pressed key.
// Single Path that combines balloon top, tapered neck, and key-shaped bottom
// so the whole figure reads as one extruded shape.
//
// Three alignment variants:
//   .center -- balloon centered above the key (default).
//   .left   -- balloon's LEFT edge aligned with key's left edge; extends right.
//              Used for the leftmost key in a row to avoid overflowing the keyboard.
//   .right  -- balloon's RIGHT edge aligned with key's right edge; extends left.
//              Used for the rightmost key in a row.

// MARK: - KeyCalloutMetrics

/// Layout ratios for the callout balloon. Scaled at use site.
enum KeyCalloutMetrics {
  static let topWidthMultiplier: CGFloat = 1.5
  static let cornerRadius: CGFloat = 8.5
  static let keyCornerRadius: CGFloat = 8.5
  /// Empirical: balances readability against breathing room around large symbols.
  static let labelFontFraction: CGFloat = 0.7
  /// Optical centering nudge — neck + key portion below pull the perceived center downward.
  static let labelOpticalOffsetFraction: CGFloat = 0.1
}

// MARK: - KeyCalloutAlignment

enum KeyCalloutAlignment {
  case center
  case left
  case right
}

// MARK: - KeyCalloutShape

struct KeyCalloutShape: Shape {

  // MARK: Internal

  let keyWidth: CGFloat
  let keyHeight: CGFloat
  let topWidth: CGFloat
  let topHeight: CGFloat
  let neckHeight: CGFloat
  let cornerRadius: CGFloat
  let keyCornerRadius: CGFloat
  /// Horizontal offset of the key portion within the top width.
  /// 0 => key flush left, (topWidth - keyWidth) => key flush right,
  /// (topWidth - keyWidth)/2 => key centered.
  let keyLeftOffset: CGFloat

  func path(in _: CGRect) -> Path {
    var path = Path()
    let keyLeft = self.keyLeftOffset
    let keyRight = keyLeft + self.keyWidth
    let topBottom = self.topHeight
    let keyTop = self.topHeight + self.neckHeight
    let keyBottom = keyTop + self.keyHeight
    self.addBalloonTop(to: &path)
    path.addLine(to: CGPoint(x: self.topWidth, y: topBottom))
    path.addCurve(
      to: CGPoint(x: keyRight, y: keyTop),
      control1: CGPoint(x: self.topWidth, y: topBottom + self.neckHeight * 0.6),
      control2: CGPoint(x: keyRight, y: keyTop - self.neckHeight * 0.6),
    )
    self.addKeyBottom(to: &path, keyLeft: keyLeft, keyRight: keyRight, keyBottom: keyBottom)
    path.addLine(to: CGPoint(x: keyLeft, y: keyTop))
    path.addCurve(
      to: CGPoint(x: 0, y: topBottom),
      control1: CGPoint(x: keyLeft, y: keyTop - self.neckHeight * 0.6),
      control2: CGPoint(x: 0, y: topBottom + self.neckHeight * 0.6),
    )
    path.addLine(to: CGPoint(x: 0, y: self.cornerRadius))
    path.closeSubpath()
    return path
  }

  // MARK: Private

  private func addBalloonTop(to path: inout Path) {
    path.move(to: CGPoint(x: 0, y: self.cornerRadius))
    path.addArc(
      center: CGPoint(x: self.cornerRadius, y: self.cornerRadius),
      radius: self.cornerRadius,
      startAngle: .degrees(180),
      endAngle: .degrees(270),
      clockwise: false,
    )
    path.addLine(to: CGPoint(x: self.topWidth - self.cornerRadius, y: 0))
    path.addArc(
      center: CGPoint(x: self.topWidth - self.cornerRadius, y: self.cornerRadius),
      radius: self.cornerRadius,
      startAngle: .degrees(270),
      endAngle: .degrees(0),
      clockwise: false,
    )
  }

  private func addKeyBottom(to path: inout Path, keyLeft: CGFloat, keyRight: CGFloat, keyBottom: CGFloat) {
    path.addLine(to: CGPoint(x: keyRight, y: keyBottom - self.keyCornerRadius))
    path.addArc(
      center: CGPoint(x: keyRight - self.keyCornerRadius, y: keyBottom - self.keyCornerRadius),
      radius: self.keyCornerRadius,
      startAngle: .degrees(0),
      endAngle: .degrees(90),
      clockwise: false,
    )
    path.addLine(to: CGPoint(x: keyLeft + self.keyCornerRadius, y: keyBottom))
    path.addArc(
      center: CGPoint(x: keyLeft + self.keyCornerRadius, y: keyBottom - self.keyCornerRadius),
      radius: self.keyCornerRadius,
      startAngle: .degrees(90),
      endAngle: .degrees(180),
      clockwise: false,
    )
  }
}

// MARK: - KeyCallout

struct KeyCallout<Label: View>: View {

  let keyWidth: CGFloat
  let keyHeight: CGFloat
  /// Vertical gap between symbol rows (already kb-scaled). Drives neck height
  /// so the tapered connector matches the visual rhythm of the row spacing.
  let rowSpacing: CGFloat
  var alignment = KeyCalloutAlignment.center
  @ViewBuilder let label: (CGFloat) -> Label

  var topWidth: CGFloat {
    self.keyWidth * KeyCalloutMetrics.topWidthMultiplier
  }

  /// One key height — fully derived from the originating key.
  var topHeight: CGFloat {
    self.keyHeight
  }

  var neckHeight: CGFloat {
    self.rowSpacing
  }

  var totalWidth: CGFloat {
    self.topWidth
  }

  var totalHeight: CGFloat {
    self.topHeight + self.neckHeight + self.keyHeight
  }

  var labelFontSize: CGFloat {
    self.topHeight * KeyCalloutMetrics.labelFontFraction
  }

  /// Where the key portion sits horizontally within `topWidth` for current alignment.
  var keyLeftOffset: CGFloat {
    switch self.alignment {
    case .center: (self.topWidth - self.keyWidth) / 2
    case .left: 0
    case .right: self.topWidth - self.keyWidth
    }
  }

  var body: some View {
    KeyCalloutShape(
      keyWidth: self.keyWidth,
      keyHeight: self.keyHeight,
      topWidth: self.topWidth,
      topHeight: self.topHeight,
      neckHeight: self.neckHeight,
      cornerRadius: KeyCalloutMetrics.cornerRadius.kbScaled,
      keyCornerRadius: KeyCalloutMetrics.keyCornerRadius.kbScaled,
      keyLeftOffset: self.keyLeftOffset,
    )
    .fill(Color(.keyBackground))
    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    .frame(width: self.totalWidth, height: self.totalHeight)
    .overlay(alignment: .top) {
      self.label(self.labelFontSize)
        .frame(width: self.topWidth, height: self.topHeight)
        .offset(y: self.topHeight * KeyCalloutMetrics.labelOpticalOffsetFraction)
    }
  }
}
