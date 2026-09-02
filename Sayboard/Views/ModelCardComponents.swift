
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

struct ModelStat: Identifiable {
  let labelKey: String
  let value: Double

  var id: String {
    self.labelKey
  }
}

struct ModelStatBars: View {

  let stats: [ModelStat]

  var body: some View {
    Grid(horizontalSpacing: 8, verticalSpacing: 6) {
      ForEach(self.stats) { stat in
        GridRow {
          Text(LocalizedStringKey(stat.labelKey))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
          ZStack(alignment: .leading) {
            Capsule()
              .fill(Color.secondary.opacity(0.15))
            Capsule()
              .fill(Color.accentColor)
              .frame(width: Self.barWidth * stat.value)
          }
          .frame(width: Self.barWidth, height: Self.barHeight)
        }
      }
    }
  }

  private static let barHeight: CGFloat = 6
  private static let barWidth: CGFloat = 50
}

struct ModelBadgePill: View {

  let text: Text
  let color: Color
  var systemImage: String?

  var body: some View {
    HStack(spacing: 4) {
      if let systemImage = self.systemImage {
        Image(systemName: systemImage)
          .font(.caption2.weight(.bold))
      }
      self.text
        .font(.caption.weight(.medium))
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .foregroundStyle(self.color)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(self.color.opacity(0.12))
    .clipShape(Capsule())
  }
}

struct ModelBadgesRow<Trailing: View>: View {

  let isActive: Bool
  @ViewBuilder let trailing: Trailing

  var body: some View {
    FlowLayout {
      ModelBadgePill(text: Text("Active"), color: .accentColor, systemImage: "checkmark")
        .fixedSize()
        .frame(width: self.isActive ? nil : 0)
        .clipped()
        .opacity(self.isActive ? 1 : 0)
      self.trailing
    }
  }
}

struct ModelLanguageTag: View {

  let languageTagKey: String
  let formattedRAM: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      self.languages
      self.memory
    }
    .foregroundStyle(.secondary)
  }

  private var languages: some View {
    HStack(spacing: 4) {
      Image(systemName: "globe")
        .font(.caption2)
      Text(LocalizedStringKey(self.languageTagKey))
        .font(.caption)
    }
    .fixedSize()
  }

  private var memory: some View {
    HStack(spacing: 4) {
      Image(systemName: "memorychip")
        .font(.caption2)
      Text("\(self.formattedRAM) RAM")
        .font(.caption)
    }
    .fixedSize()
  }
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
    .frame(minHeight: self.statusRowHeight)
    .animation(nil, value: self.downloadState)
  }

  @State private var showDeleteConfirmation = false

  private let statusRowHeight: CGFloat = 24

  private var notDownloadedView: some View {
    Button(action: self.onDownload) {
      FlowLayout(spacing: 4, lineSpacing: 2) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.caption)
        Text("Download")
          .font(.caption.weight(.medium))
          .fixedSize()
        Text(verbatim: "(\(self.formattedSize))")
          .font(.caption)
          .fixedSize()
      }
      .foregroundStyle(Color.accentColor)
    }
    .buttonStyle(.plain)
  }

  private var downloadedBadge: some View {
    HStack(spacing: 8) {
      FlowLayout(spacing: 4, lineSpacing: 2) {
        Text("Downloaded")
          .font(.caption.weight(.medium))
          .fixedSize()
        Text(verbatim: "(\(self.formattedSize))")
          .font(.caption)
          .fixedSize()
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
