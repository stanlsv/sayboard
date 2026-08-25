
import SwiftUI

struct LLMActionBar: View {

  let onSelectAction: (LLMAction, UUID?) -> Void

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6.kbScaled) {
        ForEach(
          LLMAction.enabledActions(excluding: self.keyboardState.disabledLLMActions),
          id: \.rawValue,
        ) { action in
          LLMActionChip(label: action.displayNameKey, isLocalized: true) {
            self.onSelectAction(action, nil)
          }
        }
        self.customPromptChips
      }
      .padding(.horizontal, 4.kbScaled)
    }
    .mask {
      HStack(spacing: 0) {
        LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
          .frame(width: 24.kbScaled)
        Color.black
        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
          .frame(width: 24.kbScaled)
      }
    }
    .onAppear { UIScrollView.appearance().delaysContentTouches = false }
  }

  @ViewBuilder
  private var customPromptChips: some View {
    let prompts = self.keyboardState.llmCustomPrompts
    if !prompts.isEmpty {
      Divider()
        .frame(height: 20.kbScaled)
        .padding(.horizontal, 2.kbScaled)
      ForEach(prompts) { prompt in
        LLMActionChip(label: prompt.name, isLocalized: false) {
          self.onSelectAction(.rewrite, prompt.id)
        }
      }
    }
  }

}

private struct LLMActionChip: View {

  let label: String
  let isLocalized: Bool
  let action: () -> Void

  var body: some View {
    Button(action: self.action) {
      Group {
        if self.isLocalized {
          Text(LocalizedStringKey(self.label))
        } else {
          Text(verbatim: self.label)
        }
      }
      .lineLimit(1)
      .font(.system(size: 14.kbScaled, weight: .medium))
      .padding(.horizontal, 12.kbScaled)
    }
    .buttonStyle(ActionChipStyle())
  }

}

private struct ActionChipStyle: ButtonStyle {

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .frame(height: 34.kbScaled)
      .background {
        RoundedRectangle(cornerRadius: 8.5.kbScaled, style: .continuous)
          .fill(Color(configuration.isPressed ? .keyPressedBackground : .keyBackground))
          .keyPressTransition(isPressed: configuration.isPressed)
      }
  }

}
