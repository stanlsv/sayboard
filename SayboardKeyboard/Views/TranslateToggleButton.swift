import SwiftUI
import UIKit

// MARK: - TranslateKeyStyle

private struct TranslateKeyStyle: ButtonStyle {
  let isActive: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(width: 43, height: 45)
      .background {
        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
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

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    Button {
      self.keyboardState.toggleTranslationMode()
    } label: {
      ZStack(alignment: .bottomTrailing) {
        Image(systemName: "translate")
          .font(.system(size: 18))
          .foregroundStyle(self.keyboardState.isTranslationMode ? Color.accentColor : .primary)
        Text(verbatim: "EN")
          .font(.system(size: 7, weight: .bold, design: .rounded))
          .foregroundStyle(
            self.keyboardState.isTranslationMode
              ? Color.accentColor.opacity(0.2)
              : Color.primary.opacity(0.2)
          )
          .offset(x: 2, y: 8)
      }
      .animation(.easeOut(duration: 0.12), value: self.keyboardState.isTranslationMode)
    }
    .buttonStyle(TranslateKeyStyle(isActive: self.keyboardState.isTranslationMode))
    .sensoryFeedback(.selection, trigger: self.keyboardState.isTranslationMode)
  }
}
