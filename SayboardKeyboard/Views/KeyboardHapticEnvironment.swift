import SwiftUI

// KeyboardHapticEnvironment -- Carries the user's haptic-feedback preference into the
// keyboard view tree, plus a `.gatedSensoryFeedback` modifier that fires only when enabled.

// MARK: - Environment

extension EnvironmentValues {
  @Entry var keyboardHapticsEnabled = true
}

// MARK: - View Modifier

extension View {
  /// Plays `.sensoryFeedback` only when the user has enabled keyboard haptics.
  /// UX-critical haptics that should always fire (long-press cues) must keep
  /// using plain `.sensoryFeedback`.
  func gatedSensoryFeedback(
    _ feedback: SensoryFeedback,
    trigger: some Equatable,
  ) -> some View {
    self.modifier(GatedSensoryFeedbackModifier(feedback: feedback, trigger: trigger))
  }
}

// MARK: - GatedSensoryFeedbackModifier

private struct GatedSensoryFeedbackModifier<T: Equatable>: ViewModifier {

  let feedback: SensoryFeedback
  let trigger: T

  // MARK: Internal

  func body(content: Content) -> some View {
    content.sensoryFeedback(trigger: self.trigger) { _, _ in
      self.enabled ? self.feedback : nil
    }
  }

  // MARK: Private

  @Environment(\.keyboardHapticsEnabled) private var enabled
}
