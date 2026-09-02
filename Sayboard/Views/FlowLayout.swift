
import SwiftUI

struct FlowLayout: Layout {

  var spacing: CGFloat = 6
  var lineSpacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout Void) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    let lines = self.lines(for: subviews, maxWidth: maxWidth)
    let width = lines.map(\.width).max() ?? 0
    let height = lines.map(\.height).reduce(0, +)
      + self.lineSpacing * CGFloat(max(0, lines.count - 1))
    return CGSize(width: min(width, maxWidth), height: height)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal _: ProposedViewSize,
    subviews: Subviews,
    cache _: inout Void,
  ) {
    var y = bounds.minY
    for line in self.lines(for: subviews, maxWidth: bounds.width) {
      var x = bounds.minX
      for item in line.items {
        subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
        x += item.size.width + self.spacing
      }
      y += line.height + self.lineSpacing
    }
  }

  private struct Line {
    var items = [(index: Int, size: CGSize)]()
    var width: CGFloat = 0
    var height: CGFloat = 0
  }

  private func lines(for subviews: Subviews, maxWidth: CGFloat) -> [Line] {
    var lines = [Line]()
    var current = Line()

    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
      guard size.width > 0 else { continue }

      if current.items.isEmpty {
        current = Line(items: [(index, size)], width: size.width, height: size.height)
      } else if current.width + self.spacing + size.width <= maxWidth {
        current.items.append((index, size))
        current.width += self.spacing + size.width
        current.height = max(current.height, size.height)
      } else {
        lines.append(current)
        current = Line(items: [(index, size)], width: size.width, height: size.height)
      }
    }

    if !current.items.isEmpty {
      lines.append(current)
    }
    return lines
  }
}
