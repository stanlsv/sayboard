// LLMModelCardView -- Card UI for a single LLM model variant

import SwiftUI
import UIKit

// MARK: - LLMModelCardView

struct LLMModelCardView: View {

  // MARK: Internal

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
          .lineLimit(2)
          .padding(.bottom, 4)
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

  // MARK: Private

  @Environment(\.locale) private var locale

  private let cardCornerRadius: CGFloat = 12

  private var headerRow: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text(verbatim: self.variant.displayName)
          .font(.headline)
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
        }
      }
      .animation(.easeInOut(duration: 0.35), value: self.isActive)
      Spacer()
      VStack(spacing: 6) {
        ModelStatBar(label: "quality", value: self.variant.quality)
        ModelStatBar(label: "speed", value: self.variant.speed)
      }
    }
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
