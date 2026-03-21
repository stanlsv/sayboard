import SwiftUI
import UIKit

struct OnboardingView: View {

  // MARK: Internal

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

  // MARK: Private

  @EnvironmentObject private var permissionService: PermissionService
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  @State private var step = 0

  @ViewBuilder
  private var microphoneStep: some View {
    if self.permissionService.microphoneState == .denied {
      SetupBannerView(
        title: "Microphone Access",
        subtitle: "Enable microphone access so Sayboard can hear you. Your audio never leaves your device.",
        actions: [
          SetupBannerAction(title: "Open Settings", style: .primary) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
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
          SetupBannerAction(title: "Allow", style: .primary) {
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
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
          }
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
