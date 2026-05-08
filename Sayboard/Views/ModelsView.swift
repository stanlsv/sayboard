import SwiftUI
import UIKit

// MARK: - ModelCardView

private struct ModelCardView: View {

  // MARK: Internal

  let variant: ModelVariant
  let isActive: Bool
  let downloadState: ModelDownloadState
  let preferredLanguages: Set<String>
  let onSelect: () -> Void
  let onDownload: () -> Void
  let onCancel: () -> Void
  let onRetry: () -> Void
  let onRemove: () -> Void
  let onEditLanguages: () -> Void

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 8) {
        self.headerRow
        Text(LocalizedStringKey(self.variant.descriptionKey))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .padding(.bottom, 4)
        self.bottomRow
        if self.showsLanguageSelectionRow {
          self.languageSelectionRow
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .opacity(self.variant.isSupportedOnCurrentDevice ? 1 : 0.45)
      if !self.variant.isSupportedOnCurrentDevice {
        UnsupportedModelOverlay(cornerRadius: self.cardCornerRadius)
      }
    }
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: self.cardCornerRadius))
    .overlay(
      RoundedRectangle(cornerRadius: self.cardCornerRadius)
        .stroke(self.isActive ? Color.accentColor : Color.clear, lineWidth: 2)
    )
    .contentShape(RoundedRectangle(cornerRadius: self.cardCornerRadius))
    .onTapGesture(perform: self.handleTap)
    .animation(.easeInOut(duration: 0.35), value: self.showsLanguageSelectionRow)
  }

  // MARK: Private

  @Environment(\.locale) private var locale

  private let cardCornerRadius: CGFloat = 12

  private var showsLanguageSelectionRow: Bool {
    self.isActive && self.variant.supportsLanguageSelection
  }

  private var headerRow: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text(verbatim: self.variant.displayName)
          .font(.headline)
        self.badgesRow
      }
      .animation(.easeInOut(duration: 0.35), value: self.isActive)
      Spacer()
      VStack(spacing: 6) {
        ModelStatBar(label: "accuracy", value: self.variant.accuracy)
        ModelStatBar(label: "speed", value: self.variant.speed)
      }
    }
  }

  private var badgesRow: some View {
    HStack(spacing: 0) {
      self.activeBadge
        .fixedSize()
        .frame(width: self.isActive ? nil : 0)
        .clipped()
        .opacity(self.isActive ? 1 : 0)
        .padding(.trailing, self.isActive ? 6 : 0)
      if self.variant.isRecommended {
        self.recommendedBadge
      }
      if self.variant.supportsTranslation {
        self.translationBadge
      }
    }
  }

  private var translationBadge: some View {
    Text("Translates to English")
      .font(.caption.weight(.medium))
      .foregroundStyle(.purple)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Color.purple.opacity(0.12))
      .clipShape(Capsule())
  }

  private var activeBadge: some View {
    HStack(spacing: 4) {
      Image(systemName: "checkmark")
        .font(.caption2.weight(.bold))
      Text("Active")
        .font(.caption.weight(.medium))
    }
    .foregroundStyle(Color.accentColor)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Color.accentColor.opacity(0.12))
    .clipShape(Capsule())
  }

  private var recommendedBadge: some View {
    Text("Recommended")
      .font(.caption.weight(.medium))
      .foregroundStyle(.green)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Color.green.opacity(0.12))
      .clipShape(Capsule())
  }

  private var bottomRow: some View {
    HStack(spacing: 8) {
      if !self.isDownloading {
        self.languageTag
      }
      Spacer()
      DownloadStatusView(
        formattedSize: self.variant.formattedDownloadSize(locale: self.locale),
        downloadState: self.downloadState,
        onDownload: self.onDownload,
        onCancel: self.onCancel,
        onRetry: self.onRetry,
        onRemove: self.onRemove,
      )
      .disabled(!self.variant.isSupportedOnCurrentDevice)
    }
  }

  private var languageSelectionRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      Rectangle()
        .fill(Color(.separator))
        .frame(height: 1)
      Button(action: self.onEditLanguages) {
        HStack(spacing: 6) {
          Image(systemName: "textformat")
            .font(.caption2)
          Text("Recognize")
            .font(.caption.weight(.medium))
          Spacer(minLength: 8)
          self.preferredLanguagesSummary
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.tail)
          Image(systemName: "chevron.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
    .padding(.top, 2)
  }

  @ViewBuilder
  private var preferredLanguagesSummary: some View {
    let codes = self.preferredLanguages
    if codes.isEmpty {
      Text("Auto-detect")
    } else {
      let names = codes.sorted().map { self.locale.capitalizedLanguageName(forLanguageCode: $0) }
      Text(verbatim: ListFormatter.localizedString(byJoining: names))
    }
  }

  private var isDownloading: Bool {
    if case .downloading = self.downloadState { return true }
    return false
  }

  private var languageTag: some View {
    HStack(spacing: 4) {
      Image(systemName: "globe")
        .font(.caption2)
      Text(LocalizedStringKey(self.variant.languageTagKey))
        .font(.caption)
      Text(verbatim: "\u{00b7}")
        .font(.caption.weight(.bold))
      Image(systemName: "memorychip")
        .font(.caption2)
      Text("\(self.variant.formattedRAM(locale: self.locale)) RAM")
        .font(.caption)
    }
    .foregroundStyle(.secondary)
  }

  private func handleTap() {
    switch self.downloadState {
    case .downloaded:
      self.onSelect()
    case .notDownloaded where self.variant.isSupportedOnCurrentDevice:
      self.onDownload()
    default:
      break
    }
  }

}

// MARK: - ModelTab

private enum ModelTab: String, CaseIterable {
  case speechRecognition
  case textProcessing
}

// MARK: - ModelsView

struct ModelsView: View {

  // MARK: Internal

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

  // MARK: Private

  @EnvironmentObject private var downloadService: ModelDownloadService
  @State private var selectedTab = ModelTab.speechRecognition
  @State private var selectedVariant: ModelVariant?
  @State private var selectedLanguageFilter: String?
  @State private var showLanguagePicker = false
  @State private var selectionHapticTrigger = false
  @State private var languagePrefVariant: ModelVariant?
  // In-process cache mirrored to SharedSettings via `preferenceBinding`.
  // Assumes this view is the only writer.
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

      let lhsRating = (lhs.accuracy + lhs.speed) / 2.0
      let rhsRating = (rhs.accuracy + rhs.speed) / 2.0
      return lhsRating > rhsRating
    }
  }

  private var sttContent: some View {
    Group {
      self.languageFilterButton
      VStack(spacing: 12) {
        ForEach(self.filteredAndSortedVariants) { variant in
          self.modelCard(for: variant)
        }
      }
      .animation(.easeInOut(duration: 0.35), value: self.filteredAndSortedVariants)
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
  }
}
