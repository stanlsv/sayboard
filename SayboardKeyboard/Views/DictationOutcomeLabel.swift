
import SwiftUI

struct DictationOutcomeLabel: View {

  let outcome: DictationOutcome
  let onDismiss: () -> Void

  var body: some View {
    self.labelText
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12.kbScaled)
      .padding(.top, 4.kbScaled)
      .padding(.bottom, 8.kbScaled)
      .task(id: self.outcome) {
        try? await Task.sleep(for: Self.visibleDuration)
        guard !Task.isCancelled else { return }
        self.onDismiss()
      }
  }

  private static let visibleDuration = Duration.seconds(4)

  private var labelText: Text {
    let text = Text(self.message)
    guard self.outcome == .engineFailed else { return text }
    return Text(verbatim: "\u{26A0}\u{FE0F} ") + text
  }

  private var message: LocalizedStringKey {
    switch self.outcome {
    case .noSpeech: "No speech recognized. Try speaking again"
    case .engineFailed: "Dictation failed. Try a different speech model in Sayboard"
    }
  }
}
