
import SwiftUI

struct LLMModelsSection: View {

  var body: some View {
    let variants = self.filteredAndSortedVariants
    return Group {
      if let replaced = self.llmDownloadService.replacedByUpgrade {
        self.upgradeNotice(replaced: replaced)
      }
      self.languageFilterButton
      VStack(spacing: 12) {
        ForEach(variants) { variant in
          self.modelCard(for: variant)
        }
      }
      .animation(.easeInOut(duration: 0.35), value: variants)
    }
    .sensoryFeedback(.selection, trigger: self.selectionHapticTrigger)
    .onChange(of: self.llmDownloadService.selectedVariant) {
      self.syncSelectedVariant()
    }
    .sheet(isPresented: self.$showLanguagePicker) {
      LanguagePickerView(
        mode: .single(self.$selectedLanguageFilter),
        availableLanguages: LLMModelVariant.allSupportedLanguages,
      )
    }
  }

  @EnvironmentObject private var llmDownloadService: LLMDownloadService
  @Environment(\.locale) private var locale
  @State private var selectedVariant: LLMModelVariant?
  @State private var selectedLanguageFilter: String?
  @State private var showLanguagePicker = false
  @State private var selectionHapticTrigger = false

  private var effectiveSelectedVariant: LLMModelVariant {
    self.selectedVariant ?? self.llmDownloadService.selectedVariant
  }

  private var catalogVariants: [LLMModelVariant] {
    LLMModelVariant.allCases.filter { !$0.isSuperseded || self.llmDownloadService.isDownloaded($0) }
  }

  private var filteredAndSortedVariants: [LLMModelVariant] {
    let variants =
      if let language = self.selectedLanguageFilter {
        self.catalogVariants.filter { $0.supportedLanguages.contains(language) }
      } else {
        self.catalogVariants
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

      return lhs.catalogRank > rhs.catalogRank
    }
  }

  private var upgradeNoticeHeader: some View {
    HStack(alignment: .top) {
      Text("Model updated")
        .font(.subheadline.weight(.semibold))
      Spacer()
      Button {
        self.llmDownloadService.dismissUpgradeNotice()
      } label: {
        Image(systemName: "xmark")
          .font(.caption.weight(.bold))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Dismiss")
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
      Text(self.locale.capitalizedLanguageName(forLanguageCode: code))
        .font(.subheadline)
    } else {
      Text("All languages")
        .font(.subheadline)
    }
  }

  private func upgradeNotice(replaced: LLMModelVariant) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      self.upgradeNoticeHeader
      Text("Now using \(self.effectiveSelectedVariant.displayName). \(replaced.displayName) is still on your device.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      self.upgradeNoticeActions(replaced: replaced)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  private func upgradeNoticeActions(replaced: LLMModelVariant) -> some View {
    HStack(spacing: 12) {
      Button("Switch back") {
        self.llmDownloadService.revertUpgrade()
      }
      Button("Remove", role: .destructive) {
        self.llmDownloadService.deleteReplacedModel()
      }
      Spacer()
      Text(verbatim: replaced.formattedDownloadSize(locale: self.locale))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .font(.footnote.weight(.medium))
    .buttonStyle(.plain)
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
    .equatable()
  }
}
