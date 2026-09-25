
import SwiftUI

struct OnboardingKeyboardView: View {

  let advancesWhenReady: Bool
  let onContinue: () -> Void

  var body: some View {
    OnboardingScreen {
      OnboardingHeader(
        title: "Turn On the Keyboard",
        subtitle: "In Settings, open Keyboards and turn on both switches. Full Access goes last.",
      )
      Spacer(minLength: Self.sectionSpacing)
      if self.isReady {
        self.readyCard
      } else {
        FullAccessTutorialView(reservesFullHeight: true)
      }
      Spacer(minLength: Self.sectionSpacing)
    } actions: {
      if self.isReady {
        OnboardingPrimaryButton(label: Text("Continue"), action: self.onContinue)
      } else {
        OnboardingPrimaryButton(label: Text("Open Settings")) {
          self.pipTutorialService.playTutorial(.fullAccess, language: self.appLanguage, thenOpenSettings: true)
        }
      }
    }
    .onChange(of: self.isReady) { _, isReady in
      if isReady { self.onContinue() }
    }
    .task { await self.advanceIfAlreadyReady() }
  }

  private static let sectionSpacing: CGFloat = 24
  private static let readyRowHeight: CGFloat = 52
  private static let readyCardPause = Duration.seconds(1)

  @EnvironmentObject private var permissionService: PermissionService
  @EnvironmentObject private var pipTutorialService: PiPTutorialService
  @AppStorage(SharedKey.appLanguage) private var appLanguage = AppLanguageConfig.fallback

  private var isReady: Bool {
    self.permissionService.isKeyboardAdded && self.permissionService.hasFullAccess
  }

  private var readyCard: some View {
    OnboardingCard {
      HStack(spacing: 12) {
        SetupCompletedMark()
        Text("The keyboard and Full Access are on")
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .frame(minHeight: Self.readyRowHeight)
    }
    .padding(.horizontal, 16)
  }

  private func advanceIfAlreadyReady() async {
    guard self.advancesWhenReady, self.isReady else { return }
    try? await Task.sleep(for: Self.readyCardPause)
    guard !Task.isCancelled, self.isReady else { return }
    self.onContinue()
  }

}
