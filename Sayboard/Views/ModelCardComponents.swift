// ModelCardComponents -- Reusable stat bar and download status views for model cards

import SwiftUI

// MARK: - ModelStatBar

struct ModelStatBar: View {

  // MARK: Internal

  let label: String
  let value: Double

  var body: some View {
    HStack(spacing: 8) {
      Text(LocalizedStringKey(self.label))
        .font(.caption2)
        .foregroundStyle(.secondary)
        .frame(width: self.labelWidth, alignment: .trailing)
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.secondary.opacity(0.15))
            .frame(height: self.barHeight)
          Capsule()
            .fill(Color.accentColor)
            .frame(width: geometry.size.width * self.value, height: self.barHeight)
        }
      }
      .frame(width: self.barWidth, height: self.barHeight)
    }
  }

  // MARK: Private

  private let barHeight: CGFloat = 6
  private let barWidth: CGFloat = 50
  private let labelWidth: CGFloat = 52
}

// MARK: - UnsupportedModelOverlay

struct UnsupportedModelOverlay: View {

  let cornerRadius: CGFloat

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        RoundedRectangle(cornerRadius: self.cornerRadius)
          .fill(Color.black.opacity(0.05))
        VStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.title3)
          Text("This model needs more memory (RAM) than your device has")
            .font(.caption.weight(.medium))
            .multilineTextAlignment(.center)
        }
        .foregroundStyle(.orange)
        .frame(maxWidth: geometry.size.width * 0.6)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
    }
  }
}

// MARK: - DownloadStatusView

struct DownloadStatusView: View {

  // MARK: Internal

  let formattedSize: String
  let downloadState: ModelDownloadState
  let onDownload: () -> Void
  let onCancel: () -> Void
  let onRetry: () -> Void
  let onRemove: () -> Void

  var body: some View {
    Group {
      switch self.downloadState {
      case .notDownloaded:
        self.notDownloadedView

      case .downloading(let progress):
        self.downloadingView(progress: progress)

      case .downloaded:
        self.downloadedBadge

      case .error(let message):
        self.errorView(message: message)
      }
    }
    .transition(.identity)
    .frame(height: self.statusRowHeight)
    .animation(nil, value: self.downloadState)
  }

  // MARK: Private

  @State private var showDeleteConfirmation = false

  private let statusRowHeight: CGFloat = 24

  private var notDownloadedView: some View {
    Button(action: self.onDownload) {
      HStack(spacing: 4) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.caption)
        Text("Download")
          .font(.caption.weight(.medium))
        Text(verbatim: "(\(self.formattedSize))")
          .font(.caption)
      }
      .foregroundStyle(Color.accentColor)
    }
    .buttonStyle(.plain)
  }

  private var downloadedBadge: some View {
    HStack(spacing: 8) {
      HStack(spacing: 4) {
        Text("Downloaded")
          .font(.caption.weight(.medium))
        Text(verbatim: "(\(self.formattedSize))")
          .font(.caption)
      }
      .foregroundStyle(.secondary)
      Button {
        self.showDeleteConfirmation = true
      } label: {
        Image("icon-delete")
          .resizable()
          .frame(width: 16, height: 16)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .confirmationDialog(
        "Remove Model",
        isPresented: self.$showDeleteConfirmation,
        titleVisibility: .visible,
      ) {
        Button("Remove", role: .destructive) {
          self.onRemove()
        }
      } message: {
        Text("This will free up storage. You can re-download it anytime.")
      }
    }
  }

  private func downloadingView(progress: Double) -> some View {
    let isLoadingPhase = progress >= ModelDownloadService.downloadProgressCeiling

    return HStack(spacing: 8) {
      ProgressView(value: progress)
        .tint(Color.accentColor)
        .frame(maxWidth: .infinity)
        .animation(.linear(duration: 0.2), value: progress)
      Text(verbatim: "\(Int(progress * 100))%")
        .font(.caption.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 32, alignment: .trailing)
      if !isLoadingPhase {
        Button(action: self.onCancel) {
          Image(systemName: "xmark.circle.fill")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .transition(.scale)
      }
    }
    .animation(.easeInOut(duration: 0.25), value: isLoadingPhase)
  }

  private func errorView(message: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.caption)
        .foregroundStyle(.orange)
      Text(verbatim: message)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Spacer()
      Button(action: self.onRetry) {
        Text("Retry")
          .font(.caption.weight(.medium))
          .foregroundStyle(Color.accentColor)
      }
      .buttonStyle(.plain)
    }
  }
}
