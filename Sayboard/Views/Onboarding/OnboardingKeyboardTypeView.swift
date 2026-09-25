
import SwiftUI

struct OnboardingKeyboardTypeView: View {

  let onContinue: () -> Void

  var body: some View {
    OnboardingScreen {
      OnboardingHeader(
        title: "Keyboard Type",
        subtitle: "You can change this anytime in Settings.",
      )
      Spacer(minLength: Self.sectionSpacing)
      self.cardsLayout {
        self.option(.standard, subtitle: "Big microphone button")
        self.option(.extended, subtitle: "Numbers and symbols, smaller microphone")
      }
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 16)
      Spacer(minLength: Self.sectionSpacing)
    } actions: {
      OnboardingPrimaryButton(label: Text("Continue"), action: self.onContinue)
    }
    .sensoryFeedback(.selection, trigger: self.selected)
  }

  private static let sectionSpacing: CGFloat = 20
  private static let columnSpacing: CGFloat = 10
  private static let cardPadding: CGFloat = 12
  private static let titleRowVerticalPadding: CGFloat = 6
  private static let cardCornerRadius: CGFloat = 22
  private static let selectedBorderWidth: CGFloat = 2

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var selected = SharedSettings().keyboardKind

  private var cardsLayout: AnyLayout {
    self.dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(spacing: Self.columnSpacing))
      : AnyLayout(HStackLayout(alignment: .top, spacing: Self.columnSpacing))
  }

  private func option(_ kind: KeyboardKind, subtitle: LocalizedStringKey) -> some View {
    let isSelected = self.selected == kind
    return Button {
      self.selected = kind
      SharedSettings().keyboardKind = kind
    } label: {
      VStack(spacing: 10) {
        KeyboardPhonePreview(kind: kind)
        VStack(spacing: 2) {
          HStack(spacing: 6) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
              .font(.title3)
              .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
              .accessibilityHidden(true)
            Text(LocalizedStringKey(kind.displayNameKey))
              .font(.headline)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
          .padding(.vertical, Self.titleRowVerticalPadding)
          Text(subtitle)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(Self.cardPadding)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(
        Color(.secondarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous),
      )
      .overlay {
        RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
          .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: Self.selectedBorderWidth)
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}
