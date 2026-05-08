// GlyphPath -- Renders a glyph as a SwiftUI Shape with its ink bounds centered in the rect.

import CoreText
import SwiftUI
import UIKit

// MARK: - GlyphPath

struct GlyphPath: Shape {
  let character: String
  let font: UIFont

  func path(in rect: CGRect) -> Path {
    let utf16 = Array(self.character.utf16)
    guard utf16.count == 1 else { return Path() }

    let ctFont = self.font as CTFont
    var glyph: CGGlyph = 0
    let success = CTFontGetGlyphsForCharacters(ctFont, utf16, &glyph, 1)
    guard success, glyph != 0 else { return Path() }

    guard let cgPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) else {
      return Path()
    }

    // CT path is in font space (Y-up, baseline at origin). Flip Y for SwiftUI and translate
    // so the ink bounding box's center coincides with rect's center.
    let bounds = cgPath.boundingBox
    let transform = CGAffineTransform.identity
      .translatedBy(x: rect.midX, y: rect.midY)
      .scaledBy(x: 1, y: -1)
      .translatedBy(x: -bounds.midX, y: -bounds.midY)

    return Path(cgPath).applying(transform)
  }
}

// MARK: - GlyphPath + Inclusion

extension GlyphPath {

  // MARK: Internal

  static func canRender(_ character: String) -> Bool {
    guard character.count == 1, let char = character.first else { return false }
    if char.isLetter || char.isNumber { return false }
    if Self.keepTypographic.contains(char) { return false }
    return true
  }

  // MARK: Private

  private static let keepTypographic: Set<Character> = [
    // Bottom-anchored: optical center near baseline.
    ".",
    ",",
    "_",
    // Top-anchored: optical center above geometric center.
    "^",
    "'",
    "\"",
    "*",
  ]
}
