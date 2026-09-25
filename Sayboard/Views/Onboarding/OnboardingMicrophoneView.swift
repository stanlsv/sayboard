
import SwiftUI

struct OnboardingMicrophoneView: View {

  let onContinue: () -> Void
  let onContinueWithout: () -> Void

  var body: some View {
    OnboardingScreen {
      OnboardingHeader(
        title: "Microphone Access",
        subtitle: """
          Sayboard needs the microphone to turn your speech into text. \
          Audio is processed only on this device and is never sent anywhere.
          """,
      )
      Spacer(minLength: Self.sectionSpacing)
      if self.permissionService.microphoneState == .denied {
        MicrophoneTutorialView()
      } else {
        MicrophonePromptTutorialView()
      }
      Spacer(minLength: Self.sectionSpacing)
    } actions: {
      if self.permissionService.microphoneState == .denied {
        OnboardingPrimaryButton(label: Text("Open Settings")) {
          self.pipTutorialService.playTutorial(.microphone, language: self.appLanguage, thenOpenSettings: true)
        }
        OnboardingSecondaryButton(title: "Continue Without Microphone", action: self.onContinueWithout)
      } else {
        OnboardingPrimaryButton(label: Text("Continue")) {
          if self.permissionService.microphoneState == .granted {
            self.onContinue()
          } else {
            self.permissionService.requestMicrophonePermission()
          }
        }
      }
    }
    .onChange(of: self.permissionService.microphoneState) { _, state in
      if state == .granted { self.onContinue() }
    }
  }

  private static let sectionSpacing: CGFloat = 28

  @EnvironmentObject private var permissionService: PermissionService
  @EnvironmentObject private var pipTutorialService: PiPTutorialService
  @AppStorage(SharedKey.appLanguage) private var appLanguage = AppLanguageConfig.fallback

}
