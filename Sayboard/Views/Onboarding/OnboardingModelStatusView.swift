
import SwiftUI

struct OnboardingModelStatusView: View {

  let variant: ModelVariant
  var modelLabel: Text?
  var alignment = HorizontalAlignment.leading

  var body: some View {
    VStack(alignment: self.alignment, spacing: 8) {
      HStack(spacing: 10) {
        self.statusLine
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)
      if case .error(let message) = self.state {
        ModelNoticeRow(text: Text(message))
      }
    }
    .frame(maxWidth: .infinity, minHeight: Self.minHeight, alignment: Alignment(horizontal: self.alignment, vertical: .center))
    .padding(.horizontal, 16)
  }

  private static let minHeight: CGFloat = 44
  private static let progressWidth: CGFloat = 80

  @EnvironmentObject private var downloadService: ModelDownloadService

  private var state: ModelDownloadState {
    self.downloadService.state(for: self.variant)
  }

  @ViewBuilder
  private var statusLine: some View {
    switch self.state {
    case .downloaded:
      SetupCompletedMark()
      Text("\(self.variant.displayName) is ready")

    case .downloading(let progress) where progress < ModelDownloadService.downloadProgressCeiling:
      ProgressView(value: progress)
        .frame(width: Self.progressWidth)
      Text("Downloading \(self.variant.displayName)")
      Text(progress, format: .percent.precision(.fractionLength(0)))
        .monospacedDigit()

    case .downloading:
      ProgressView()
      Text("Preparing \(self.variant.displayName)…")

    case .error:
      if let label = self.modelLabel {
        label
      } else {
        Button("Retry") {
          self.downloadService.dismissError(variant: self.variant)
          self.downloadService.startDownload(variant: self.variant)
        }
      }

    case .notDownloaded:
      if let label = self.modelLabel {
        label
      } else {
        Button("Download \(self.variant.displayName)") {
          self.downloadService.startDownload(variant: self.variant)
        }
      }
    }
  }
}
