
import CoreText
import SwiftUI
import UIKit

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

    let bounds = cgPath.boundingBox
    let transform = CGAffineTransform.identity
      .translatedBy(x: rect.midX, y: rect.midY)
      .scaledBy(x: 1, y: -1)
      .translatedBy(x: -bounds.midX, y: -bounds.midY)

    return Path(cgPath).applying(transform)
  }
}

extension GlyphPath {

  static func canRender(_ character: String) -> Bool {
    guard character.count == 1, let char = character.first else { return false }
    if char.isLetter || char.isNumber { return false }
    if Self.keepTypographic.contains(char) { return false }
    return true
  }

  private static let keepTypographic: Set<Character> = [
    ".",
    ",",
    "_",
    "^",
    "'",
    "\"",
    "*",
  ]
}
