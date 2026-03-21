import SwiftUI
import UIKit

// MARK: - SetupBannerAction

struct SetupBannerAction {
  enum Style {
    case primary
    case secondary
  }

  let title: LocalizedStringKey
  let style: Style
  let action: () -> Void
}

// MARK: - SetupBannerView

struct SetupBannerView: View {

  // MARK: Internal

  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey
  let actions: [SetupBannerAction]
  var tutorial: AnyView?

  var body: some View {
    ZStack {
      self.opaqueBackground
        .ignoresSafeArea()

      VStack(spacing: 24) {
        VStack(spacing: 8) {
          Text(self.title)
            .font(.title2.bold())
            .multilineTextAlignment(.center)

          Text(self.subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)

        if let tutorial {
          tutorial
        }

        self.actionButtons
          .padding(.top, 8)
      }
    }
  }

  // MARK: Private

  /// Resolved opaque background color.
  /// Uses `systemGroupedBackground` for a subtle light-gray tint in light mode,
  /// resolved to an opaque value to prevent translucency on iOS 26 (Liquid Glass).
  private var opaqueBackground: Color {
    Color(UIColor.systemGroupedBackground.resolvedColor(with: UITraitCollection.current))
  }

  private var actionButtons: some View {
    VStack(spacing: 12) {
      ForEach(Array(self.actions.enumerated()), id: \.offset) { _, action in
        self.actionButton(action)
      }
    }
  }

  @ViewBuilder
  private func actionButton(_ action: SetupBannerAction) -> some View {
    switch action.style {
    case .primary:
      Button(action: action.action) {
        Text(action.title)
          .frame(width: 180)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)

    case .secondary:
      Button(action: action.action) {
        Text(action.title)
          .frame(width: 120)
      }
      .buttonStyle(.bordered)
      .controlSize(.large)
    }
  }
}
