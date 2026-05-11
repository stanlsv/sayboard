import SwiftUI
import UIKit

// MARK: - KeyContent

enum KeyContent {
  case text(LocalizedStringKey)
  case systemImage(String)
  case symbol(String, fontSize: CGFloat? = nil)
}

// MARK: - KeyButton

struct KeyButton: View {

  // MARK: Internal

  let content: KeyContent
  var fixedWidth: CGFloat?
  var shape = KeyShape.rounded
  var pressEffect = true
  var fillOnPress = false
  var showsCallout = false
  /// Used as the callout's neck height (vertical gap between rows of keys).
  var calloutRowSpacing: CGFloat = 0
  /// Callout alignment — `.left`/`.right` for edge keys to keep the balloon inside the keyboard.
  var calloutAlignment = KeyCalloutAlignment.center
  /// `true` for input keys (letters, digits, symbols, punct, return, delete, page-swap).
  /// `false` for chrome action buttons (settings, undo/redo, delete-all) — those don't
  /// participate in the global keyboard-haptics toggle, mirroring stock-keyboard behavior.
  var firesHaptic = true
  let action: () -> Void

  var body: some View {
    Button {
      if self.firesHaptic { self.tapCount &+= 1 }
      self.action()
    } label: {
      self.contentView
    }
    .buttonStyle(RectKeyStyle(
      fixedWidth: self.fixedWidth,
      shape: self.shape,
      pressEffect: self.pressEffect,
      fillOnPress: self.fillOnPress,
      pressedBinding: self.showsCallout ? self.$isPressed : nil,
    ))
    .overlay(alignment: .top) {
      if self.showsCallout {
        self.calloutOverlay
      }
    }
    .zIndex(self.showsCallout && self.isPressed ? 100 : 0)
    .gatedSensoryFeedback(.selection, trigger: self.tapCount)
  }

  // MARK: Private

  @State private var isPressed = false
  @State private var tapCount = 0

  @ViewBuilder
  private var contentView: some View {
    switch self.content {
    case .text(let key):
      Text(key)
        .font(.system(size: 16.kbScaled))

    case .systemImage(let name):
      Image(systemName: name)
        .font(.system(size: 18.kbScaled))

    case .symbol(let symbol, let fontSize):
      self.symbolText(symbol, fontSize: fontSize)
    }
  }

  private var calloutOverlay: some View {
    GeometryReader { geo in
      let topW = geo.size.width * KeyCalloutMetrics.topWidthMultiplier
      let neckH = self.calloutRowSpacing
      let totalH = geo.size.height + neckH + geo.size.height
      let posX = self.calloutPositionX(keyWidth: geo.size.width, topWidth: topW)
      KeyCallout(
        keyWidth: geo.size.width,
        keyHeight: geo.size.height,
        rowSpacing: self.calloutRowSpacing,
        alignment: self.calloutAlignment,
      ) { fontSize in
        self.calloutLabel(fontSize: fontSize)
      }
      .opacity(self.isPressed ? 1 : 0)
      .position(x: posX, y: geo.size.height - totalH / 2)
      .transaction(value: self.isPressed) { transaction in
        transaction.animation = self.isPressed ? nil : .easeOut(duration: 0.02).delay(0.01)
      }
    }
    .allowsHitTesting(false)
  }

  private func calloutPositionX(keyWidth: CGFloat, topWidth: CGFloat) -> CGFloat {
    switch self.calloutAlignment {
    case .center: keyWidth / 2
    case .left: topWidth / 2
    case .right: keyWidth - topWidth / 2
    }
  }

  private func calloutLabel(fontSize: CGFloat) -> some View {
    Group {
      switch self.content {
      case .text(let key):
        Text(key)
          .font(.system(size: fontSize))

      case .systemImage(let name):
        Image(systemName: name)
          .font(.system(size: fontSize))

      case .symbol(let symbol, _):
        self.calloutSymbolText(symbol, fontSize: fontSize)
      }
    }
    .foregroundStyle(.primary)
  }

  @ViewBuilder
  private func symbolText(_ symbol: String, fontSize: CGFloat?) -> some View {
    let size = (fontSize ?? 22).kbScaled
    if GlyphPath.canRender(symbol) {
      GlyphPath(
        character: symbol,
        font: UIFont.systemFont(ofSize: size, weight: .regular),
      )
      .fill(.primary)
      .frame(width: size, height: size)
    } else {
      Text(verbatim: symbol)
        .font(.system(size: size, weight: .regular))
    }
  }

  @ViewBuilder
  private func calloutSymbolText(_ symbol: String, fontSize: CGFloat) -> some View {
    if GlyphPath.canRender(symbol) {
      GlyphPath(
        character: symbol,
        font: UIFont.systemFont(ofSize: fontSize, weight: .regular),
      )
      .fill(.primary)
      .frame(width: fontSize, height: fontSize)
    } else {
      Text(verbatim: symbol)
        .font(.system(size: fontSize, weight: .regular))
    }
  }
}
