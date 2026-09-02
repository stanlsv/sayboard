import SwiftUI
import UIKit

enum ModelTab: String, CaseIterable {
  case speechRecognition
  case textProcessing
}

struct ModelsView: View {

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if !self.hasAnyDownloadedModel {
          self.noModelBanner
        }

        Picker(selection: self.$selectedTab) {
          Text("Speech Recognition").tag(ModelTab.speechRecognition)
          Text("Text Processing").tag(ModelTab.textProcessing)
        } label: {
          EmptyView()
        }
        .pickerStyle(.segmented)
        .padding(.vertical, 4)

        switch self.selectedTab {
        case .speechRecognition:
          self.sttContent
        case .textProcessing:
          LLMModelsSection()
        }
      }
      .padding()
      .animation(.easeInOut(duration: 0.25), value: self.selectedTab)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Models")
    .sheet(isPresented: self.$showLanguagePicker) {
      LanguagePickerView(
        mode: .single(self.$selectedLanguageFilter),
        availableLanguages: SpeechLanguages.all,
      )
    }
    .sheet(item: self.$languagePrefVariant) { variant in
      LanguagePickerView(
        mode: .multi(self.preferenceBinding(for: variant)),
        availableLanguages: variant.supportedLanguages,
        titleKey: "Recognize",
        autoDetectKey: "Auto-detect (any language)",
        footnoteKey: "Sayboard will prioritize these languages. Pick a single language for the most accurate recognition.",
      )
    }
    .sensoryFeedback(.selection, trigger: self.selectionHapticTrigger)
    .onChange(of: self.downloadService.selectedVariant) {
      self.syncSelectedVariant()
    }
  }

  @EnvironmentObject private var downloadService: ModelDownloadService
  @SceneStorage("modelsTab") private var selectedTab = ModelTab.speechRecognition
  @State private var selectedVariant: ModelVariant?
  @State private var selectedLanguageFilter: String?
  @State private var showLanguagePicker = false
  @State private var selectionHapticTrigger = false
  @State private var languagePrefVariant: ModelVariant?
  @State private var preferences: [String: Set<String>] = Self.loadPreferences()
  @Environment(\.locale) private var locale

  private var effectiveSelectedVariant: ModelVariant {
    self.selectedVariant ?? self.downloadService.selectedVariant
  }

  private var hasAnyDownloadedModel: Bool {
    ModelVariant.allCases.contains { self.downloadService.isDownloaded($0) }
  }

  private var filteredAndSortedVariants: [ModelVariant] {
    let variants =
      if let language = self.selectedLanguageFilter {
        ModelVariant.allCases.filter { $0.supportedLanguages.contains(language) }
      } else {
        Array(ModelVariant.allCases)
      }
    let selected = self.effectiveSelectedVariant
    return variants.sorted { lhs, rhs in
      let lhsActive = selected == lhs && self.downloadService.isDownloaded(lhs)
      let rhsActive = selected == rhs && self.downloadService.isDownloaded(rhs)
      if lhsActive != rhsActive { return lhsActive }

      let lhsDownloaded = self.downloadService.isDownloaded(lhs)
      let rhsDownloaded = self.downloadService.isDownloaded(rhs)
      if lhsDownloaded != rhsDownloaded { return lhsDownloaded }

      if lhs.isRecommended != rhs.isRecommended { return lhs.isRecommended }

      return lhs.catalogRank > rhs.catalogRank
    }
  }

  private var sttContent: some View {
    let variants = self.filteredAndSortedVariants
    return Group {
      self.languageFilterButton
      VStack(spacing: 12) {
        ForEach(variants) { variant in
          self.modelCard(for: variant)
        }
      }
      .animation(.easeInOut(duration: 0.35), value: variants)
    }
  }

  private var noModelBanner: some View {
    HStack(spacing: 10) {
      Image(systemName: "arrow.down.circle")
        .font(.title3)
        .foregroundStyle(.orange)
      Text("Download a model to start voice input")
        .font(.subheadline.weight(.medium))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.orange.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private var languageFilterButton: some View {
    HStack(spacing: 8) {
      self.filterChip
      self.filterResetButton
    }
  }

  private var filterChip: some View {
    Button {
      self.showLanguagePicker = true
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "globe")
          .font(.subheadline)
        self.filterLabel
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption2)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        self.selectedLanguageFilter != nil
          ? Color.accentColor.opacity(0.12)
          : Color(.secondarySystemGroupedBackground)
      )
      .foregroundStyle(
        self.selectedLanguageFilter != nil
          ? Color.accentColor
          : Color.secondary
      )
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var filterResetButton: some View {
    if self.selectedLanguageFilter != nil {
      Button {
        self.selectedLanguageFilter = nil
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.body)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  private var filterLabel: some View {
    if let code = self.selectedLanguageFilter {
      Text(self.locale.capitalizedLanguageName(forLanguageCode: code))
        .font(.subheadline)
    } else {
      Text("All languages")
        .font(.subheadline)
    }
  }

  private static func loadPreferences() -> [String: Set<String>] {
    SharedSettings().preferredLanguagesPerVariant.mapValues(Set.init)
  }

  private func preferenceBinding(for variant: ModelVariant) -> Binding<Set<String>> {
    Binding(
      get: { self.preferences[variant.rawValue] ?? [] },
      set: { newValue in
        if newValue.isEmpty {
          self.preferences.removeValue(forKey: variant.rawValue)
        } else {
          self.preferences[variant.rawValue] = newValue
        }
        SharedSettings().setPreferredLanguages(newValue, for: variant)
      },
    )
  }

  private func syncSelectedVariant() {
    let current = SharedSettings().selectedVariant
    if self.selectedVariant != current {
      withAnimation(.easeInOut(duration: 0.35)) {
        self.selectedVariant = current
      }
    }
  }

  private func modelCard(for variant: ModelVariant) -> some View {
    let downloadState = self.downloadService.state(for: variant)
    let isActive = self.effectiveSelectedVariant == variant && self.downloadService.isDownloaded(variant)

    return ModelCardView(
      variant: variant,
      isActive: isActive,
      downloadState: downloadState,
      preferredLanguages: self.preferences[variant.rawValue] ?? [],
      onSelect: {
        self.selectionHapticTrigger.toggle()
        withAnimation(.easeInOut(duration: 0.35)) {
          self.selectedVariant = variant
          self.downloadService.selectVariant(variant)
        }
      },
      onDownload: {
        self.downloadService.startDownload(variant: variant)
      },
      onCancel: {
        self.downloadService.cancelDownload(variant: variant)
      },
      onRetry: {
        self.downloadService.dismissError(variant: variant)
        self.downloadService.startDownload(variant: variant)
      },
      onRemove: {
        withAnimation(.easeInOut(duration: 0.35)) {
          self.downloadService.deleteModel(variant: variant)
          self.syncSelectedVariant()
        }
      },
      onEditLanguages: {
        self.languagePrefVariant = variant
      },
    )
    .equatable()
  }
}
