
import SwiftUI
import UIKit

struct OnboardingLanguagesView: View {

  let previousChoice: ModelVariant?
  @Binding var draft: OnboardingLanguageDraft

  let onChoose: (ModelVariant) -> Void

  var body: some View {
    OnboardingScreen {
      OnboardingHeader(
        title: "Your Languages",
        subtitle: "Which languages do you dictate in? We’ll pick a speech model for them.",
      )
      Spacer(minLength: Self.firstSectionSpacing)
      self.languagesSection
      OnboardingModelStatusView(variant: self.suggested, modelLabel: self.modelLine)
        .padding(.horizontal, 16)
        .padding(.top, Self.statusSpacing)
      Spacer(minLength: Self.firstSectionSpacing)
    } actions: {
      OnboardingPrimaryButton(label: self.primaryLabel) {
        self.choose(self.suggested)
      }
      OnboardingSecondaryButton(title: "Choose Another Model") {
        self.showsOtherModels = true
      }
    }
    .onAppear {
      self.loadDeviceLanguagesIfNeeded()
      self.languagesOnAppear = Set(self.draft.languages)
    }
    .sheet(isPresented: self.$showsLanguagePicker) {
      LanguagePickerView(mode: .multi(self.languageSelection), autoDetectKey: "Any language")
    }
    .sheet(isPresented: self.$showsOtherModels, onDismiss: self.finishSheetChoice) {
      OnboardingModelsSheet(
        languages: self.draft.languages,
        recommended: self.suggested,
        choice: self.$sheetChoice,
      )
    }
  }

  private static let firstSectionSpacing: CGFloat = 24
  private static let statusSpacing: CGFloat = 12
  private static let chipSpacing: CGFloat = 8
  private static let cardPadding: CGFloat = 16
  private static let chipAnimation = Animation.easeInOut(duration: 0.35)

  @EnvironmentObject private var downloadService: ModelDownloadService
  @Environment(\.locale) private var locale
  @State private var showsLanguagePicker = false
  @State private var showsOtherModels = false
  @State private var sheetChoice: ModelVariant?
  @State private var languagesOnAppear = Set<String>()

  private var recommended: ModelVariant {
    SpeechModelRecommendation.recommendedVariant(languages: self.draft.languages)
  }

  private var suggested: ModelVariant {
    guard let previous = self.previousChoice, Set(self.draft.languages) == self.languagesOnAppear else {
      return self.recommended
    }
    return previous
  }

  private var modelLine: Text {
    Text("Speech model: \(Text(verbatim: self.suggested.displayName).fontWeight(.semibold).foregroundStyle(.primary))")
  }

  private var primaryLabel: Text {
    switch self.downloadService.state(for: self.suggested) {
    case .downloaded, .downloading:
      Text("Continue")
    case .notDownloaded, .error:
      Text("Download · \(self.suggested.formattedDownloadSize(locale: self.locale))")
    }
  }

  private var languageSelection: Binding<Set<String>> {
    Binding(
      get: { Set(self.draft.languages) },
      set: { chosen in
        withAnimation(Self.chipAnimation) {
          let kept = self.draft.languages.filter { chosen.contains($0) }
          self.draft.languages = kept + chosen.subtracting(kept).sorted()
        }
      },
    )
  }

  private var languagesSection: some View {
    OnboardingCard {
      VStack(alignment: .leading, spacing: 12) {
        FlowLayout(spacing: Self.chipSpacing, lineSpacing: Self.chipSpacing) {
          if self.draft.languages.isEmpty {
            OnboardingLanguageChip(title: Text("Any language"), style: .neutral)
          }
          ForEach(self.draft.languages, id: \.self) { code in
            OnboardingLanguageChip(
              title: Text(verbatim: self.locale.capitalizedLanguageName(forLanguageCode: code)),
              style: .removable,
            ) {
              withAnimation(Self.chipAnimation) { self.draft.languages.removeAll { $0 == code } }
            }
          }
          OnboardingLanguageChip(title: Text("Add Language"), style: .add) {
            self.showsLanguagePicker = true
          }
        }
        if !self.draft.languages.isEmpty {
          Text("These are the languages you speak, taken from your device and keyboards. The app language stays the same.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(Self.cardPadding)
    }
    .padding(.horizontal, 16)
  }

  private func loadDeviceLanguagesIfNeeded() {
    guard !self.draft.isLoaded else { return }
    let keyboards = UITextInputMode.activeInputModes.compactMap(\.primaryLanguage)
    self.draft.languages = SpeechModelRecommendation.speechCodes(from: Locale.preferredLanguages + keyboards)
    self.draft.isLoaded = true
  }

  private func choose(_ variant: ModelVariant) {
    self.cancelUnfinishedDownload(of: self.previousChoice, replacedBy: variant)
    SharedSettings().setPreferredLanguages(
      SpeechModelRecommendation.preferredLanguages(for: variant, from: self.draft.languages),
      for: variant,
    )
    if variant.isSupportedOnCurrentDevice {
      switch self.downloadService.state(for: variant) {
      case .notDownloaded:
        self.downloadService.startDownload(variant: variant)

      case .error:
        self.downloadService.dismissError(variant: variant)
        self.downloadService.startDownload(variant: variant)

      case .downloading, .downloaded:
        break
      }
    }
    self.onChoose(variant)
  }

  private func finishSheetChoice() {
    guard let choice = self.sheetChoice else { return }
    self.sheetChoice = nil
    self.cancelUnfinishedDownload(of: self.previousChoice, replacedBy: choice)
    self.onChoose(choice)
  }

  private func cancelUnfinishedDownload(of previous: ModelVariant?, replacedBy variant: ModelVariant) {
    guard let previous, previous != variant, !self.downloadService.isDownloaded(previous) else { return }
    if
      case .downloading(let progress) = self.downloadService.state(for: previous),
      progress < ModelDownloadService.downloadProgressCeiling
    {
      self.downloadService.cancelDownload(variant: previous)
    }
  }
}

struct OnboardingLanguageDraft: Equatable {
  var isLoaded = false
  var languages = [String]()
}

private struct OnboardingLanguageChip: View {

  enum Style {
    case removable
    case add
    case neutral
  }

  let title: Text
  let style: Style
  var action: (() -> Void)?

  var body: some View {
    Button {
      self.action?()
    } label: {
      HStack(spacing: 6) {
        if self.style == .add {
          Image(systemName: "plus")
            .font(.caption.weight(.bold))
        }
        self.title
        if self.style == .removable {
          Image(systemName: "xmark")
            .font(.caption2.weight(.bold))
        }
      }
      .font(.subheadline.weight(.medium))
      .padding(.horizontal, Self.horizontalPadding)
      .padding(.vertical, Self.verticalPadding)
      .frame(minHeight: Self.minHeight)
      .foregroundStyle(self.style == .neutral ? Color.secondary : Color.accentColor)
      .background(self.fill, in: Capsule())
    }
    .buttonStyle(.plain)
    .disabled(self.action == nil)
  }

  private static let horizontalPadding: CGFloat = 12
  private static let verticalPadding: CGFloat = 8
  private static let minHeight: CGFloat = 44
  private static let tintOpacity = 0.12

  private var fill: Color {
    switch self.style {
    case .removable: Color.accentColor.opacity(Self.tintOpacity)
    case .add, .neutral: Color(.tertiarySystemFill)
    }
  }
}

struct OnboardingModelsSheet: View {

  let languages: [String]
  let recommended: ModelVariant

  @Binding var choice: ModelVariant?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          Text("These models cover your languages. A model starts downloading as soon as you tap it.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
          ForEach(self.alternatives) { variant in
            self.card(for: variant)
          }
        }
        .padding(16)
      }
      .background(Color(.systemGroupedBackground))
      .navigationTitle("Other Models")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { self.dismiss() }
        }
      }
    }
  }

  @EnvironmentObject private var downloadService: ModelDownloadService
  @Environment(\.dismiss) private var dismiss

  private var alternatives: [ModelVariant] {
    SpeechModelRecommendation.alternatives(languages: self.languages, excluding: self.recommended)
  }

  private func card(for variant: ModelVariant) -> some View {
    ModelCardView(
      variant: variant,
      isActive: false,
      downloadState: self.downloadService.state(for: variant),
      preferredLanguages: [],
      onSelect: {
        self.choice = variant
        self.dismiss()
      },
      onDownload: { self.download(variant) },
      onCancel: { self.downloadService.cancelDownload(variant: variant) },
      onRetry: {
        self.downloadService.dismissError(variant: variant)
        self.download(variant)
      },
      onRemove: { self.downloadService.deleteModel(variant: variant) },
      onEditLanguages: { },
    )
    .equatable()
  }

  private func download(_ variant: ModelVariant) {
    self.downloadService.startDownload(variant: variant)
    self.choice = variant
    self.dismiss()
  }
}
