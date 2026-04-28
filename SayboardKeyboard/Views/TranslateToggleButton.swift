import SwiftUI
import UIKit

// MARK: - TranslateKeyStyle

private struct TranslateKeyStyle: ButtonStyle {
  let fixedWidth: CGFloat
  let isActive: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(width: self.fixedWidth, height: 45.kbScaled)
      .background {
        RoundedRectangle(cornerRadius: 8.5.kbScaled, style: .continuous)
          .fill(self.backgroundColor(isPressed: configuration.isPressed))
      }
      .animation(.easeOut(duration: 0.12), value: self.isActive)
  }

  private func backgroundColor(isPressed: Bool) -> Color {
    if self.isActive {
      return isPressed ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.12)
    }
    return Color(isPressed ? .keyPressedBackground : .keyBackground)
  }
}

// MARK: - TranslateToggleButton

struct TranslateToggleButton: View {

  let fixedWidth: CGFloat

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    Button {
      self.keyboardState.toggleTranslationMode()
    } label: {
      ZStack(alignment: .bottomTrailing) {
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
          .offset(x: 2.kbScaled, y: 8.kbScaled)
      }
      .animation(.easeOut(duration: 0.12), value: self.keyboardState.isTranslationMode)
    }
    .buttonStyle(TranslateKeyStyle(fixedWidth: self.fixedWidth, isActive: self.keyboardState.isTranslationMode))
    .sensoryFeedback(.selection, trigger: self.keyboardState.isTranslationMode)
  }
}
