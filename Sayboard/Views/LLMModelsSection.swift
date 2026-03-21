// LLMModelsSection -- LLM model list section for the Models tab

import SwiftUI

// MARK: - LLMModelsSection

struct LLMModelsSection: View {

  // MARK: Internal

  var body: some View {
    Group {
      self.languageFilterButton
      VStack(spacing: 12) {
        ForEach(self.filteredAndSortedVariants) { variant in
          self.modelCard(for: variant)
        }
      }
      .animation(.easeInOut(duration: 0.35), value: self.filteredAndSortedVariants)
    }
    .sensoryFeedback(.selection, trigger: self.selectionHapticTrigger)
    .onChange(of: self.llmDownloadService.selectedVariant) {
      self.syncSelectedVariant()
    }
    .sheet(isPresented: self.$showLanguagePicker) {
      LanguagePickerView(
        selectedLanguage: self.$selectedLanguageFilter,
        availableLanguages: LLMModelVariant.allSupportedLanguages,
      )
    }
  }

  // MARK: Private

  @EnvironmentObject private var llmDownloadService: LLMDownloadService
  @Environment(\.locale) private var locale
  @State private var selectedVariant: LLMModelVariant?
  @State private var selectedLanguageFilter: String?
  @State private var showLanguagePicker = false
  @State private var selectionHapticTrigger = false

  private var effectiveSelectedVariant: LLMModelVariant {
    self.selectedVariant ?? self.llmDownloadService.selectedVariant
  }

  private var filteredAndSortedVariants: [LLMModelVariant] {
    let variants =
      if let language = self.selectedLanguageFilter {
        LLMModelVariant.allCases.filter { $0.supportedLanguages.contains(language) }
      } else {
        Array(LLMModelVariant.allCases)
      }
    let selected = self.effectiveSelectedVariant
    return variants.sorted { lhs, rhs in
      let lhsActive = selected == lhs && self.llmDownloadService.isDownloaded(lhs)
      let rhsActive = selected == rhs && self.llmDownloadService.isDownloaded(rhs)
      if lhsActive != rhsActive { return lhsActive }

      let lhsDownloaded = self.llmDownloadService.isDownloaded(lhs)
      let rhsDownloaded = self.llmDownloadService.isDownloaded(rhs)
      if lhsDownloaded != rhsDownloaded { return lhsDownloaded }

      if lhs.isRecommended != rhs.isRecommended { return lhs.isRecommended }

      let lhsRating = (lhs.quality + lhs.speed) / 2.0
      let rhsRating = (rhs.quality + rhs.speed) / 2.0
      return lhsRating > rhsRating
    }
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
      Text(self.languageName(for: code))
        .font(.subheadline)
    } else {
      Text("All languages")
        .font(.subheadline)
    }
  }

  private func languageName(for code: String) -> String {
    guard let name = self.locale.localizedString(forLanguageCode: code) else {
      return code
    }
    return name.prefix(1).uppercased() + name.dropFirst()
  }

  private func syncSelectedVariant() {
    let current = SharedSettings().selectedLLMVariant
    if self.selectedVariant != current {
      withAnimation(.easeInOut(duration: 0.35)) {
        self.selectedVariant = current
      }
    }
  }

  private func modelCard(for variant: LLMModelVariant) -> some View {
    let downloadState = self.llmDownloadService.state(for: variant)
    let isActive = self.effectiveSelectedVariant == variant && self.llmDownloadService.isDownloaded(variant)

    return LLMModelCardView(
      variant: variant,
      isActive: isActive,
      downloadState: downloadState,
      onSelect: {
        self.selectionHapticTrigger.toggle()
        withAnimation(.easeInOut(duration: 0.35)) {
          self.selectedVariant = variant
          self.llmDownloadService.selectVariant(variant)
        }
      },
      onDownload: {
        self.llmDownloadService.startDownload(variant: variant)
      },
      onCancel: {
        self.llmDownloadService.cancelDownload(variant: variant)
      },
      onRetry: {
        self.llmDownloadService.dismissError(variant: variant)
        self.llmDownloadService.startDownload(variant: variant)
      },
      onRemove: {
        withAnimation(.easeInOut(duration: 0.35)) {
          self.llmDownloadService.deleteModel(variant: variant)
          self.syncSelectedVariant()
        }
      },
    )
  }
}
