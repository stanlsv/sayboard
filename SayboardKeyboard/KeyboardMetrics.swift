// KeyboardMetrics -- Centralized scaling for iPad vs iPhone keyboard dimensions

import UIKit

// MARK: - KeyboardMetrics

@MainActor
enum KeyboardMetrics {

  /// iPhone portrait base height: 14.5 (top) + 168 (micRow) + 8.5 (spacing) + 49 (bottom) = 240
  static let baseHeight: CGFloat = 240
  /// Extra height added when the LLM action bar is visible (top 8 + chip 34)
  static let baseActionBarExtra: CGFloat = 42

  /// Keyboard height for the current device. Uses Apple's system keyboard ratio:
  /// iPad portrait 264 / iPhone portrait 216 = 1.222x → 240 * (264/216) ≈ 293.
  static let height: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 293 : baseHeight

  /// Scale factor relative to iPhone baseline. 1.0 on iPhone, ~1.22 on iPad.
  static let scale: CGFloat = height / baseHeight

  /// Scaled action bar extra height.
  static let actionBarExtraHeight: CGFloat = baseActionBarExtra * scale

  /// Total keyboard height including optional action bar.
  static func totalHeight(actionBarVisible: Bool) -> CGFloat {
    self.height + (actionBarVisible ? self.actionBarExtraHeight : 0)
  }
}

// MARK: - Numeric + Scaled

extension CGFloat {
  /// Multiplies by the current keyboard scale factor (1.0 on iPhone, ~1.22 on iPad).
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
