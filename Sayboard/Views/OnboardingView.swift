import SwiftUI

struct OnboardingView: View {

  var body: some View {
    NavigationStack {
      Group {
        switch self.step {
        case 0:
          self.microphoneStep
        default:
          self.keyboardStep
        }
      }
    }
    .onChange(of: self.permissionService.microphoneState) { _, newState in
      if newState == .granted {
        self.step = 1
      }
    }
    .onChange(of: self.permissionService.isKeyboardAdded) { _, _ in
      self.completeOnboardingIfReady()
    }
    .onChange(of: self.permissionService.hasFullAccess) { _, _ in
      self.completeOnboardingIfReady()
    }
    .onChange(of: self.scenePhase) { _, newPhase in
      if newPhase == .active {
        self.completeOnboardingIfReady()
      }
    }
    .onAppear {
      if self.permissionService.microphoneState == .granted {
        self.step = 1
      }
    }
    .interactiveDismissDisabled()
  }

  private static let defaultLanguage = AppLanguageConfig.fallback

  @EnvironmentObject private var permissionService: PermissionService
  @EnvironmentObject private var pipTutorialService: PiPTutorialService
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(SharedKey.appLanguage) private var appLanguage = defaultLanguage
  @State private var step = 0

  @ViewBuilder
  private var microphoneStep: some View {
    if self.permissionService.microphoneState == .denied {
      SetupBannerView(
        title: "Microphone Access",
        subtitle: "Enable microphone access so Sayboard can hear you. Your audio never leaves your device.",
        actions: [
          SetupBannerAction(title: "Open Settings", style: .primary) {
            self.pipTutorialService.playTutorial(.microphone, language: self.appLanguage, thenOpenSettings: true)
          },
          SetupBannerAction(title: "Skip", style: .secondary) {
            self.step = 1
          },
        ],
        tutorial: AnyView(MicrophoneTutorialView()),
      )
    } else {
      SetupBannerView(
        title: "Microphone Access",
        subtitle: "Enable microphone access so Sayboard can hear you. Your audio never leaves your device.",
        actions: [
          SetupBannerAction(title: "Continue", style: .primary) {
            self.permissionService.requestMicrophonePermission()
          }
        ],
      )
    }
  }

  private var keyboardStep: some View {
    SetupBannerView(
      title: "Add Keyboard",
      subtitle: "Sayboard needs to be added as a keyboard to use voice dictation in any app.",
      actions: [
        SetupBannerAction(title: "Open Settings", style: .primary) {
          self.pipTutorialService.playTutorial(.fullAccess, language: self.appLanguage, thenOpenSettings: true)
        }
      ],
      tutorial: AnyView(FullAccessTutorialView(includeFullAccessRow: true)),
    )
  }

  private func completeOnboardingIfReady() {
    guard
      self.step == 1,
      self.permissionService.isKeyboardAdded,
      self.permissionService.hasFullAccess
    else { return }
    self.completeOnboarding()
  }

  private func completeOnboarding() {
    UserDefaults.standard.set(true, forKey: SharedKey.hasCompletedOnboarding)
    self.dismiss()
  }
}
