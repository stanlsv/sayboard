import SwiftUI
import UIKit

struct SetupBannerAction {
  enum Style {
    case primary
    case secondary
  }

  let title: LocalizedStringKey
  let style: Style
  let action: () -> Void
}

struct SetupBannerView: View {

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

  @Environment(\.colorScheme) private var colorScheme

  private var opaqueBackground: Color {
    let style: UIUserInterfaceStyle = self.colorScheme == .dark ? .dark : .light
    let traits = UITraitCollection { mutableTraits in
      mutableTraits.userInterfaceStyle = style
      mutableTraits.userInterfaceLevel = .elevated
    }
    return Color(UIColor.systemGroupedBackground.resolvedColor(with: traits))
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
