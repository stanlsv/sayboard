
import SwiftUI

struct ModelCardView: View, Equatable {

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
          .lineLimit(5)
          .padding(.bottom, 4)
        if let failure = self.downloadState.errorMessage {
          ModelNoticeRow(text: Text(failure))
        } else if self.showsUpdateNotice {
          ModelNoticeRow(text: Text("Removed by an update — download again"))
        }
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

  nonisolated static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.variant == rhs.variant
      && lhs.isActive == rhs.isActive
      && lhs.downloadState == rhs.downloadState
      && lhs.preferredLanguages == rhs.preferredLanguages
  }

  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private let cardCornerRadius: CGFloat = 12

  private var showsLanguageSelectionRow: Bool {
    self.isActive && self.variant.supportsLanguageSelection
  }

  private var showsUpdateNotice: Bool {
    self.variant == .parakeetV3
      && self.downloadState == .notDownloaded
      && SharedSettings().parakeetV3NeedsRedownload
  }

  @ViewBuilder
  private var headerRow: some View {
    if self.dynamicTypeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 6) {
        self.titleAndBadges
        self.statBars
      }
    } else {
      HStack(alignment: .top) {
        self.titleAndBadges
        Spacer()
        self.statBars
      }
    }
  }

  private var titleAndBadges: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(verbatim: self.variant.displayName)
        .font(.headline)
      ModelBadgesRow(isActive: self.isActive) {
        if self.variant.isRecommended {
          ModelBadgePill(text: Text("Recommended"), color: .green)
        }
        if self.variant.supportsTranslation {
          ModelBadgePill(text: Text("Translates to English"), color: .purple)
        }
      }
    }
    .animation(.easeInOut(duration: 0.35), value: self.isActive)
  }

  private var statBars: some View {
    ModelStatBars(stats: [
      ModelStat(labelKey: "accuracy", value: self.variant.accuracy),
      ModelStat(labelKey: "speed", value: self.variant.speed),
    ])
  }

  @ViewBuilder
  private var bottomRow: some View {
    if self.dynamicTypeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 6) {
        self.collapsibleLanguageTag
        self.downloadStatus
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    } else {
      HStack(spacing: self.isDownloading ? 0 : 8) {
        self.collapsibleLanguageTag
        self.downloadStatus
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
  }

  private var collapsibleLanguageTag: some View {
    self.languageTag
      .fixedSize(horizontal: true, vertical: false)
      .frame(width: self.isDownloading ? 0 : nil, alignment: .leading)
      .opacity(self.isDownloading ? 0 : 1)
  }

  private var downloadStatus: some View {
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
    ModelLanguageTag(
      languageTagKey: self.variant.languageTagKey,
      formattedRAM: self.variant.formattedRAM(locale: self.locale),
    )
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
