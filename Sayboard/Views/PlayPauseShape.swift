import SwiftUI

// PlayPauseShape -- Morphing shape: play triangle splits into two pause bars

struct PlayPauseShape: Shape {

  // MARK: Internal

  /// 0 = play (triangle), 1 = pause (two bars)
  var progress: Double

  var animatableData: Double {
    get { self.progress }
    set { self.progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let width = rect.width
    let height = rect.height
    let factor = CGFloat(progress)
    let outerRadius: CGFloat = 1.5
    let innerRadius = outerRadius * factor
    let tipGap: CGFloat = 0.5

    var path = Path()

    // Left piece: triangle left half -> left bar
    let leftPoints = [
      CGPoint(x: 0, y: 0),
      CGPoint(x: lerp(width * 0.5, width * 0.35, factor), y: lerp(height * 0.25, 0, factor)),
      CGPoint(x: lerp(width * 0.5, width * 0.35, factor), y: lerp(height * 0.75, height, factor)),
      CGPoint(x: 0, y: height),
    ]
    self.addRoundedPolygon(to: &path, points: leftPoints, radii: [outerRadius, innerRadius, innerRadius, outerRadius])

    // Right piece: triangle right half (collapsed) -> right bar
    // tipGap separates the two tip points so the arc can round the corner
    let rightPoints = [
      CGPoint(x: lerp(width * 0.5, width * 0.65, factor), y: lerp(height * 0.25, 0, factor)),
      CGPoint(x: width, y: lerp(height * 0.5 - tipGap, 0, factor)),
      CGPoint(x: width, y: self.lerp(height * 0.5 + tipGap, height, factor)),
      CGPoint(x: self.lerp(width * 0.5, width * 0.65, factor), y: self.lerp(height * 0.75, height, factor)),
    ]
    self.addRoundedPolygon(to: &path, points: rightPoints, radii: [innerRadius, outerRadius, outerRadius, innerRadius])

    return path
  }

  // MARK: Private

  private func addRoundedPolygon(to path: inout Path, points: [CGPoint], radii: [CGFloat]) {
    guard points.count >= 3, radii.count == points.count else { return }
    let last = points[points.count - 1]
    let first = points[0]
    path.move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
    for index in 0 ..< points.count {
      let next = points[(index + 1) % points.count]
      path.addArc(tangent1End: points[index], tangent2End: next, radius: radii[index])
    }
    path.closeSubpath()
  }

  private func lerp(_ from: CGFloat, _ to: CGFloat, _ factor: CGFloat) -> CGFloat {
    from + (to - from) * factor
  }
}
