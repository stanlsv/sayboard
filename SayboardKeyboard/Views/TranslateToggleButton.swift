import SwiftUI
import UIKit

private struct TranslateKeyStyle: ButtonStyle {

  let fixedWidth: CGFloat
  let isActive: Bool
  var shape = KeyShape.rounded

  func makeBody(configuration: Configuration) -> some View {
    let fill = self.backgroundColor(isPressed: configuration.isPressed)
    return configuration.label
      .frame(width: self.fixedWidth, height: 45.kbScaled)
      .keyBackground(shape: self.shape, fill: fill, isPressed: configuration.isPressed)
      .animation(.easeOut(duration: 0.12), value: self.isActive)
  }

  private func backgroundColor(isPressed: Bool) -> Color {
    if self.isActive {
      return isPressed ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.12)
    }
    return Color(isPressed ? .keyPressedBackground : .keyBackground)
  }
}

struct TranslateToggleButton: View {

  let fixedWidth: CGFloat
  var shape = KeyShape.rounded
  var compactStyle = false

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    let zAlignment: Alignment = self.compactStyle ? .bottom : .bottomTrailing
    let enXOffset: CGFloat = self.compactStyle ? 0 : 2.kbScaled
    let enYOffset: CGFloat = self.compactStyle ? 7.kbScaled : 8.kbScaled
    return Button {
      self.keyboardState.toggleTranslationMode()
    } label: {
      ZStack(alignment: zAlignment) {
        Image(systemName: "translate")
          .font(.system(size: 18.kbScaled))
          .foregroundStyle(self.keyboardState.isTranslationMode ? Color.accentColor : .primary)
        Text(verbatim: "EN")
          .font(.system(size: 7.kbScaled, weight: .bold, design: .rounded))
          .foregroundStyle(
            self.keyboardState.isTranslationMode
              ? Color.accentColor.opacity(0.2)
              : Color.primary.opacity(0.2)
          )
          .offset(x: enXOffset, y: enYOffset)
      }
      .animation(.easeOut(duration: 0.12), value: self.keyboardState.isTranslationMode)
    }
    .buttonStyle(TranslateKeyStyle(
      fixedWidth: self.fixedWidth,
      isActive: self.keyboardState.isTranslationMode,
      shape: self.shape,
    ))
    .gatedSensoryFeedback(.selection, trigger: self.keyboardState.isTranslationMode)
  }
}
