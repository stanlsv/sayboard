// LLMErrorPrompt -- Full-screen error prompt shown when an LLM action cannot proceed

import SwiftUI

// MARK: - LLMError

enum LLMError {
  case noTextBeforeCursor

  // MARK: Internal

  var icon: String {
    switch self {
    case .noTextBeforeCursor: "character.cursor.ibeam"
    }
  }

  var message: LocalizedStringKey {
    switch self {
    case .noTextBeforeCursor:
      "To use AI actions, make sure the text field has text and the cursor is after it"
    }
  }

  var buttonTitle: LocalizedStringKey {
    switch self {
    case .noTextBeforeCursor: "OK"
    }
  }
}

// MARK: - LLMErrorPrompt

struct LLMErrorPrompt: View {

  let error: LLMError

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: self.error.icon)
        .font(.system(size: 40))
        .foregroundStyle(.blue)

      Text(self.error.message)
        .font(.subheadline.weight(.semibold))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Button {
        withAnimation(.easeOut(duration: 0.12)) { self.keyboardState.llmError = nil }
      } label: {
        Text(self.error.buttonTitle)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 20)
          .frame(minHeight: 40)
          .background(.blue, in: Capsule())
      }
      .padding(.horizontal, 32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
