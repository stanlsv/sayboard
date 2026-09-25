
import SwiftUI
import UIKit

struct KeyboardLayoutPreview: View {

  static let backdrop = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.106, green: 0.106, blue: 0.114, alpha: 1)
      : UIColor(red: 0.875, green: 0.878, blue: 0.902, alpha: 1)
  })

  static let keyFill = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark ? .systemGray4 : .white
  })

  let kind: KeyboardKind

  var body: some View {
    VStack(spacing: 0) {
      switch self.kind {
      case .standard: self.standardLayout
      case .extended: self.extendedLayout
      }
    }
    .padding(.top, Self.topPadding)
    .frame(width: Self.width, height: Self.size(for: self.kind).height, alignment: .top)
    .background(Self.backdrop)
    .accessibilityHidden(true)
  }

  static func size(for kind: KeyboardKind) -> CGSize {
    CGSize(width: Self.width, height: kind == .standard ? Self.standardHeight : Self.extendedHeight)
  }

  private static let width: CGFloat = 390
  private static let standardHeight: CGFloat = 240
  private static let extendedHeight: CGFloat = 289.5
  private static let topPadding: CGFloat = 14.5
  private static let rowSpacing: CGFloat = 8.5
  private static let keyHeight: CGFloat = 45
  private static let keyRadius: CGFloat = 8.5
  private static let keySpacing: CGFloat = 6
  private static let sideKeyWidth: CGFloat = 45
  private static let returnKeyWidth: CGFloat = 96
  private static let edgeInset: CGFloat = 4
  private static let symbolSize: CGFloat = 18
  private static let characterSize: CGFloat = 22
  private static let micRowHeight: CGFloat = 168
  private static let micDiameter: CGFloat = 106
  private static let micTop: CGFloat = 28
  private static let micGlyph = CGSize(width: 56, height: 42)
  private static let chromeRowHeight: CGFloat = 57
  private static let chromeInset: CGFloat = 12
  private static let compactMicGlyph = CGSize(width: 32.06, height: 24.04)
  private static let punctuationKeyWidth: CGFloat = 44.87
  private static let wideKeyWidth: CGFloat = 54.84
  private static let groupGap: CGFloat = 12
  private static let spaceGlyphBottom: CGFloat = 10
  private static let numbersRow = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
  private static let symbolsRow = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
  private static let punctuationRow = [".", ",", "?", "!", "'"]

  private var standardLayout: some View {
    VStack(spacing: Self.rowSpacing) {
      ZStack(alignment: .top) {
        HStack(alignment: .bottom) {
          self.symbolKey("gearshape", width: Self.sideKeyWidth)
          Spacer(minLength: 0)
          self.symbolKey("delete.left", width: Self.sideKeyWidth)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        MicMorphShape(frameIndex: 0)
          .fill(.primary)
          .frame(width: Self.micGlyph.width, height: Self.micGlyph.height)
          .frame(width: Self.micDiameter, height: Self.micDiameter)
          .background(Self.keyFill, in: Circle())
          .padding(.top, Self.micTop)
      }
      .padding(.horizontal, Self.edgeInset)
      .frame(height: Self.micRowHeight)
      self.bottomRow
    }
  }

  private var extendedLayout: some View {
    VStack(spacing: Self.rowSpacing) {
      HStack {
        self.symbolKey("gearshape", width: Self.sideKeyWidth, shape: .pill)
        Spacer(minLength: 0)
        MicMorphShape(frameIndex: 0)
          .fill(.primary)
          .frame(width: Self.compactMicGlyph.width, height: Self.compactMicGlyph.height)
          .frame(width: Self.returnKeyWidth, height: Self.keyHeight)
          .background(Self.keyFill, in: Capsule())
      }
      .padding(.horizontal, Self.chromeInset)
      .frame(height: Self.chromeRowHeight)
      self.characterRow(Self.numbersRow)
      self.characterRow(Self.symbolsRow)
      HStack(spacing: 0) {
        self.textKey("#+=", width: Self.wideKeyWidth, size: Self.symbolSize)
        HStack(spacing: Self.keySpacing) {
          ForEach(Self.punctuationRow, id: \.self) { self.textKey($0, width: Self.punctuationKeyWidth) }
        }
        .padding(.horizontal, Self.groupGap)
        self.symbolKey("delete.left", width: Self.wideKeyWidth)
      }
      .padding(.horizontal, Self.edgeInset)
      self.bottomRow
    }
  }

  private var bottomRow: some View {
    HStack(spacing: Self.keySpacing) {
      self.symbolKey("globe", width: Self.sideKeyWidth)
      self.symbolKey("trash", width: Self.sideKeyWidth)
      Image(systemName: "space")
        .font(.system(size: Self.characterSize))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, Self.spaceGlyphBottom)
        .frame(height: Self.keyHeight)
        .background(Self.keyFill, in: RoundedRectangle(cornerRadius: Self.keyRadius, style: .continuous))
      self.symbolKey("return.left", width: Self.returnKeyWidth)
    }
    .padding(.horizontal, Self.edgeInset)
  }

  private func characterRow(_ characters: [String]) -> some View {
    HStack(spacing: Self.keySpacing) {
      ForEach(characters, id: \.self) { self.textKey($0, width: nil) }
    }
    .padding(.horizontal, Self.edgeInset)
  }

  private func textKey(_ text: String, width: CGFloat?, size: CGFloat = Self.characterSize) -> some View {
    Text(verbatim: text)
      .font(.system(size: size))
      .frame(maxWidth: width ?? .infinity)
      .frame(width: width, height: Self.keyHeight)
      .background(Self.keyFill, in: RoundedRectangle(cornerRadius: Self.keyRadius, style: .continuous))
  }

  @ViewBuilder
  private func symbolKey(_ name: String, width: CGFloat, shape: KeyPreviewShape = .rounded) -> some View {
    let glyph = Image(systemName: name)
      .font(.system(size: Self.symbolSize))
      .frame(width: width, height: Self.keyHeight)
    switch shape {
    case .rounded:
      glyph.background(Self.keyFill, in: RoundedRectangle(cornerRadius: Self.keyRadius, style: .continuous))
    case .pill:
      glyph.background(Self.keyFill, in: Capsule())
    }
  }
}

private enum KeyPreviewShape {
  case rounded
  case pill
}
