// LLMActionBar -- Horizontal scrolling row of LLM action chips shown at top of keyboard

import SwiftUI

// MARK: - LLMActionBar

struct LLMActionBar: View {

  // MARK: Internal

  let onSelectAction: (LLMAction, UUID?) -> Void

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
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
      .padding(.horizontal, 4)
    }
    .onAppear { UIScrollView.appearance().delaysContentTouches = false }
  }

  // MARK: Private

  @ViewBuilder
  private var customPromptChips: some View {
    let prompts = self.keyboardState.llmCustomPrompts
    if !prompts.isEmpty {
      Divider()
        .frame(height: 20)
        .padding(.horizontal, 2)
      ForEach(prompts) { prompt in
        LLMActionChip(label: prompt.name, isLocalized: false) {
          self.onSelectAction(.rewrite, prompt.id)
        }
      }
    }
  }

}

// MARK: - LLMActionChip

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
      .font(.system(size: 14, weight: .medium))
      .padding(.horizontal, 12)
    }
    .buttonStyle(ActionChipStyle())
  }

}

// MARK: - ActionChipStyle

private struct ActionChipStyle: ButtonStyle {

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .frame(height: 34)
      .background {
        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
          .fill(Color(configuration.isPressed ? .keyPressedBackground : .keyBackground))
      }
  }

}
