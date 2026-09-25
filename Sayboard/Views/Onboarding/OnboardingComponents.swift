
import SwiftUI

struct OnboardingScreen<Content: View, Actions: View>: View {

  @ViewBuilder let content: Content
  @ViewBuilder let actions: Actions

  var body: some View {
    ScrollView {
      MinHeightLayout(minHeight: self.visibleHeight) {
        VStack(spacing: 0) {
          self.content
        }
        .padding(.bottom, Self.contentBottomPadding)
      }
    }
    .scrollBounceBehavior(.basedOnSize)
    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { self.visibleHeight = $0 }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(spacing: Self.actionSpacing) {
        self.actions
      }
      .padding(.horizontal, Self.actionsHorizontalPadding)
      .padding(.top, Self.actionsTopPadding)
      .padding(.bottom, Self.actionsBottomPadding)
      .background(Color(.systemGroupedBackground))
    }
  }

  private static var contentBottomPadding: CGFloat {
    16
  }

  private static var actionSpacing: CGFloat {
    4
  }

  private static var actionsHorizontalPadding: CGFloat {
    24
  }

  private static var actionsTopPadding: CGFloat {
    12
  }

  private static var actionsBottomPadding: CGFloat {
    8
  }

  @State private var visibleHeight: CGFloat = 0

}

private struct MinHeightLayout: Layout {
  let minHeight: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
    guard let subview = subviews.first else { return .zero }
    let ideal = subview.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
    return CGSize(width: proposal.width ?? ideal.width, height: max(ideal.height, self.minHeight))
  }

  func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
    subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
  }
}

struct OnboardingHeader: View {

  let title: LocalizedStringKey
  var subtitle: LocalizedStringKey?
  var isCompact = false

  var body: some View {
    VStack(spacing: 8) {
      Text(self.title)
        .font(self.isCompact ? .title2.bold() : .title.bold())
      if let subtitle = self.subtitle {
        Text(subtitle)
          .font(.body)
          .foregroundStyle(.secondary)
      }
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, Self.horizontalPadding)
    .padding(.top, self.isCompact ? Self.compactTopPadding : Self.topPadding)
  }

  private static let horizontalPadding: CGFloat = 28
  private static let topPadding: CGFloat = 32
  private static let compactTopPadding: CGFloat = 12
}

struct OnboardingCard<Content: View>: View {

  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      self.content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      Color(.secondarySystemGroupedBackground),
      in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous),
    )
  }

  private static var cornerRadius: CGFloat {
    26
  }
}

struct OnboardingIconTile: View {

  let systemImage: String
  var tint = Color.accentColor

  var body: some View {
    Image(systemName: self.systemImage)
      .font(.system(size: Self.size * Self.glyphRatio, weight: .medium))
      .foregroundStyle(self.tint)
      .frame(width: Self.size, height: Self.size)
      .background(
        self.tint.opacity(Self.fillOpacity),
        in: RoundedRectangle(cornerRadius: Self.size * Self.cornerRatio, style: .continuous),
      )
      .accessibilityHidden(true)
  }

  private static let size: CGFloat = 32
  private static let glyphRatio = 0.55
  private static let cornerRatio = 0.27
  private static let fillOpacity = 0.12
}

struct OnboardingOptionCard<Content: View>: View {

  let title: LocalizedStringKey
  let subtitle: LocalizedStringKey
  let isSelected: Bool
  let action: () -> Void
  @ViewBuilder let content: Content

  var body: some View {
    Button(action: self.action) {
      VStack(spacing: 10) {
        HStack(spacing: 10) {
          Image(systemName: self.isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(self.isSelected ? Color.accentColor : Color(.tertiaryLabel))
            .accessibilityHidden(true)
          VStack(alignment: .leading, spacing: 2) {
            Text(self.title)
              .font(.headline)
            Text(self.subtitle)
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 0)
        }
        self.content
      }
      .padding(Self.padding)
      .background(
        Color(.secondarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous),
      )
      .overlay {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
          .strokeBorder(self.isSelected ? Color.accentColor : .clear, lineWidth: Self.selectedBorderWidth)
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(self.isSelected ? .isSelected : [])
  }

  private static var padding: CGFloat {
    14
  }

  private static var cornerRadius: CGFloat {
    22
  }

  private static var selectedBorderWidth: CGFloat {
    2
  }
}

struct OnboardingPrimaryButton: View {
  let label: Text
  var isEnabled = true
  let action: () -> Void

  var body: some View {
    Button(action: self.action) {
      self.label
        .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.capsule)
    .controlSize(.large)
    .disabled(!self.isEnabled)
  }
}

struct OnboardingSecondaryButton: View {

  let title: LocalizedStringKey
  let action: () -> Void

  var body: some View {
    Button(action: self.action) {
      Text(self.title)
        .frame(maxWidth: .infinity, minHeight: Self.minHeight)
    }
  }

  private static var minHeight: CGFloat {
    44
  }
}

struct OnboardingStepIndicator: View {

  let current: Int
  let total: Int

  var body: some View {
    HStack(spacing: Self.spacing) {
      ForEach(0 ..< self.total, id: \.self) { index in
        Capsule()
          .fill(index < self.current ? Color.accentColor : Color(.systemFill))
          .frame(width: Self.segmentWidth, height: Self.segmentHeight)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Step \(self.current) of \(self.total)"))
  }

  private static let spacing: CGFloat = 4
  private static let segmentWidth: CGFloat = 16
  private static let segmentHeight: CGFloat = 5
}
