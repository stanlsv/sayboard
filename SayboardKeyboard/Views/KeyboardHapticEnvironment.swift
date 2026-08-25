import SwiftUI

extension EnvironmentValues {
  @Entry var keyboardHapticsEnabled = true
}

extension View {
  func gatedSensoryFeedback(
    _ feedback: SensoryFeedback,
    trigger: some Equatable,
  ) -> some View {
    self.modifier(GatedSensoryFeedbackModifier(feedback: feedback, trigger: trigger))
  }
}

private struct GatedSensoryFeedbackModifier<T: Equatable>: ViewModifier {

  let feedback: SensoryFeedback
  let trigger: T

  func body(content: Content) -> some View {
    content.sensoryFeedback(trigger: self.trigger) { _, _ in
      self.enabled ? self.feedback : nil
    }
  }

  @Environment(\.keyboardHapticsEnabled) private var enabled
}
