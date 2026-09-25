
import SwiftUI

@MainActor
enum OnboardingTextEntry {
  static var isVisible = false

  static func stylingHost(_ storedHost: String?) -> String? {
    self.isVisible ? nil : storedHost
  }
}

extension View {
  func onboardingTextEntry(isActive: Bool, isPractice: Bool = false) -> some View {
    self.modifier(OnboardingTextEntryMarker(isActive: isActive, isPractice: isPractice))
  }
}

private struct OnboardingTextEntryMarker: ViewModifier {

  let isActive: Bool
  let isPractice: Bool

  func body(content: Content) -> some View {
    content
      .onAppear(perform: self.update)
      .onChange(of: self.isActive) { self.update() }
      .onChange(of: self.scenePhase) { self.update() }
      .onDisappear { self.mark(false) }
  }

  @Environment(\.scenePhase) private var scenePhase

  private func update() {
    self.mark(self.isActive && self.scenePhase != .background)
  }

  private func mark(_ visible: Bool) {
    OnboardingTextEntry.isVisible = visible
    if self.isPractice {
      SharedSettings().onboardingPracticeProcessID = visible ? Int(ProcessInfo.processInfo.processIdentifier) : nil
    }
  }
}
