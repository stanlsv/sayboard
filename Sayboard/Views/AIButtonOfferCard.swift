
import SwiftUI

struct AIButtonOfferCard: View {

  static let variant = LLMModelVariant.allCases.first(where: \.isRecommended) ?? .gemma3OneQAT

  let onClose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        OnboardingIconTile(systemImage: "sparkles", tint: .purple)
        Text("Try the AI Button")
          .font(.headline)
        Spacer(minLength: 8)
        Button(action: self.onClose) {
          Image(systemName: "xmark")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: Self.closeSize, height: Self.closeSize)
            .background(Color(.tertiarySystemFill), in: Circle())
            .frame(width: Self.closeTapSize, height: Self.closeTapSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Not Now")
      }
      self.demo
      AIButtonOfferAction(variant: Self.variant)
    }
  }

  private static let closeSize: CGFloat = 30
  private static let closeTapSize: CGFloat = 44
  private static let demoPadding: CGFloat = 14
  private static let demoCornerRadius: CGFloat = 14
  private static let rewriteLabelPadding = EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
  private static let rewriteTintOpacity = 0.12

  private var demo: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("so yeah i cant come tomorrow cause im sick")
      HStack(spacing: 8) {
        self.hairline
        Label("Rewrite", systemImage: "sparkles")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.purple)
          .padding(Self.rewriteLabelPadding)
          .background(Color.purple.opacity(Self.rewriteTintOpacity), in: Capsule())
          .fixedSize()
        self.hairline
      }
      Text("I can’t come tomorrow — I’m sick.")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(Self.demoPadding)
    .background(
      Color(.tertiarySystemBackground),
      in: RoundedRectangle(cornerRadius: Self.demoCornerRadius, style: .continuous),
    )
  }

  private var hairline: some View {
    Rectangle()
      .fill(Color(.separator))
      .frame(height: 0.5)
      .accessibilityHidden(true)
  }
}

private struct AIButtonOfferAction: View {

  let variant: LLMModelVariant

  var body: some View {
    switch self.llmDownloadService.state(for: self.variant) {
    case .downloading(let progress):
      DownloadProgressRow(name: self.variant.displayName, progress: progress)

    case .error(let message):
      VStack(alignment: .leading, spacing: 8) {
        Text(message)
          .font(.footnote)
          .foregroundStyle(.red)
        self.downloadButton
      }

    case .notDownloaded, .downloaded:
      self.downloadButton
    }
  }

  @EnvironmentObject private var llmDownloadService: LLMDownloadService
  @Environment(\.locale) private var locale

  private var downloadButton: some View {
    Button {
      self.llmDownloadService.startDownload(variant: self.variant)
    } label: {
      Text("Download · \(self.variant.formattedDownloadSize(locale: self.locale))")
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.capsule)
    .controlSize(.large)
  }
}
