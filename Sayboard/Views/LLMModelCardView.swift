
import SwiftUI
import UIKit

struct LLMModelCardView: View, Equatable {

  let variant: LLMModelVariant
  let isActive: Bool
  let downloadState: ModelDownloadState
  let onSelect: () -> Void
  let onDownload: () -> Void
  let onCancel: () -> Void
  let onRetry: () -> Void
  let onRemove: () -> Void

  var body: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 8) {
        self.headerRow
        Text(LocalizedStringKey(self.variant.descriptionKey))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(3)
          .padding(.bottom, 4)
        if let failure = self.downloadState.errorMessage {
          ModelNoticeRow(text: Text(failure))
        }
        self.bottomRow
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
  }

  nonisolated static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.variant == rhs.variant
      && lhs.isActive == rhs.isActive
      && lhs.downloadState == rhs.downloadState
  }

  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private let cardCornerRadius: CGFloat = 12

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
        } else if let successor = self.variant.successor {
          ModelBadgePill(text: Text("Replaced by \(successor.displayName)"), color: .orange)
        }
      }
    }
    .animation(.easeInOut(duration: 0.35), value: self.isActive)
  }

  private var statBars: some View {
    ModelStatBars(stats: [
      ModelStat(labelKey: "quality", value: self.variant.quality),
      ModelStat(labelKey: "speed", value: self.variant.speed),
    ])
  }

  private var languageTag: some View {
    ModelLanguageTag(
      languageTagKey: self.variant.languageTagKey,
      formattedRAM: self.variant.formattedRAM(locale: self.locale),
    )
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

  private var isDownloading: Bool {
    if case .downloading = self.downloadState { return true }
    return false
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
