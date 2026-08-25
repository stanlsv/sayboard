
import UIKit

@MainActor
enum KeyboardMetrics {

  static let baseHeight: CGFloat = 240
  static let baseExtendedHeight: CGFloat = 289.5
  static let baseActionBarExtra: CGFloat = 42

  static let height: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 293 : baseHeight

  static let scale: CGFloat = height / baseHeight

  static let extendedHeight: CGFloat = baseExtendedHeight * scale

  static let actionBarExtraHeight: CGFloat = baseActionBarExtra * scale

  static func totalHeight(actionBarVisible: Bool, kind: KeyboardKind) -> CGFloat {
    let base = kind == .extended ? self.extendedHeight : self.height
    return base + (actionBarVisible ? self.actionBarExtraHeight : 0)
  }
}

extension CGFloat {
  @MainActor
  var kbScaled: CGFloat {
    self * KeyboardMetrics.scale
  }
}

extension Double {
  @MainActor
  var kbScaled: CGFloat {
    CGFloat(self) * KeyboardMetrics.scale
  }
}

extension Int {
  @MainActor
  var kbScaled: CGFloat {
    CGFloat(self) * KeyboardMetrics.scale
  }
}
