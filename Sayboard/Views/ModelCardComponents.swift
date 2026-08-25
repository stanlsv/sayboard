
import SwiftUI

struct ModelNoticeRow: View {
  let text: Text

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.caption)
        .foregroundStyle(.orange)
      self.text
        .font(.caption)
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(.bottom, 4)
  }
}

struct ModelStatBar: View {

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

  private let barHeight: CGFloat = 6
  private let barWidth: CGFloat = 50
  private let labelWidth: CGFloat = 52
}

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

struct DownloadStatusView: View {

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

      case .error:
        self.errorView()
      }
    }
    .transition(.identity)
    .frame(height: self.statusRowHeight)
    .animation(nil, value: self.downloadState)
  }

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

  private func errorView() -> some View {
    HStack(spacing: 8) {
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
