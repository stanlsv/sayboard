
import SwiftUI

struct SetupCardView: View {

  let checklist: SetupChecklist

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text("Finish Setup")
          .font(.headline)
        Spacer(minLength: 8)
        Text("\(self.rowCount) left")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      self.rows
    }
  }

  @EnvironmentObject private var permissionService: PermissionService
  @EnvironmentObject private var pipTutorialService: PiPTutorialService
  @AppStorage(SharedKey.appLanguage) private var appLanguage = AppLanguageConfig.fallback

  private var keyboardReady: Bool {
    self.checklist.keyboardAdded && self.checklist.fullAccessGranted
  }

  private var rowCount: Int {
    [self.checklist.microphoneGranted, self.keyboardReady, self.checklist.hasUsableModel].count { !$0 }
  }

  private var microphoneButtonTitle: LocalizedStringKey {
    self.permissionService.microphoneState == .undetermined ? "Continue" : "Turn On"
  }

  @ViewBuilder
  private var rows: some View {
    if !self.checklist.microphoneGranted {
      SetupCardRow(
        systemImage: "mic.slash",
        title: "Microphone",
        subtitle: "Dictation doesn’t work without it",
      ) {
        Button(self.microphoneButtonTitle, action: self.turnOnMicrophone)
          .setupCardButton()
      }
    }
    if !self.keyboardReady {
      SetupCardRow(
        systemImage: "lock.open",
        title: "Keyboard and Full Access",
        subtitle: "Without them the keyboard can’t dictate",
      ) {
        Button("Turn On") {
          self.pipTutorialService.playTutorial(.fullAccess, language: self.appLanguage, thenOpenSettings: true)
        }
        .setupCardButton()
      }
    }
    if !self.checklist.hasUsableModel {
      SetupCardModelRow(variant: self.modelVariant)
    }
  }

  private var modelVariant: ModelVariant {
    OnboardingRecordStore().load().chosenModel.flatMap(ModelVariant.init(rawValue:)) ?? SharedSettings().selectedVariant
  }

  private func turnOnMicrophone() {
    if self.permissionService.microphoneState == .undetermined {
      self.permissionService.requestMicrophonePermission()
    } else {
      self.pipTutorialService.playTutorial(.microphone, language: self.appLanguage, thenOpenSettings: true)
    }
  }
}

private struct SetupCardRow<Action: View>: View {

  let systemImage: String
  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey
  @ViewBuilder let action: Action

  var body: some View {
    HStack(spacing: 12) {
      OnboardingIconTile(systemImage: self.systemImage, tint: .orange)
      VStack(alignment: .leading, spacing: 2) {
        Text(self.title)
          .font(.subheadline.weight(.semibold))
        Text(self.subtitle)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      self.action
    }
  }

}

private struct SetupCardModelRow: View {

  let variant: ModelVariant

  var body: some View {
    HStack(spacing: 12) {
      OnboardingIconTile(systemImage: "arrow.down.circle")
      if case .downloading(let progress) = self.downloadService.state(for: self.variant) {
        DownloadProgressRow(name: self.variant.displayName, progress: progress)
      } else {
        VStack(alignment: .leading, spacing: 2) {
          Text("Speech Model")
            .font(.subheadline.weight(.semibold))
          Text("Download a model to start voice input")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        NavigationLink {
          ModelsView()
        } label: {
          Text("Choose")
        }
        .setupCardButton()
      }
    }
  }

  @EnvironmentObject private var downloadService: ModelDownloadService
}

extension View {
  fileprivate func setupCardButton() -> some View {
    self
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.capsule)
      .controlSize(.small)
  }
}
