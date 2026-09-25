
import SwiftUI

struct OnboardingWritingStyleView: View {

  let isLast: Bool
  let onContinue: () -> Void

  var body: some View {
    OnboardingScreen {
      OnboardingHeader(
        title: "Writing Style",
        subtitle: "Choose how dictated text is formatted. You can change this anytime in Settings.",
      )
      Spacer(minLength: Self.sectionSpacing)
      VStack(spacing: 12) {
        ForEach(WritingStyle.allCases, id: \.self) { style in
          self.option(style)
        }
      }
      .padding(.horizontal, 16)
      Spacer(minLength: Self.sectionSpacing)
    } actions: {
      OnboardingPrimaryButton(label: self.isLast ? Text("Done") : Text("Continue"), action: self.onContinue)
      if self.canStyleApps {
        OnboardingSecondaryButton(title: "Customize for Individual Apps") {
          self.showsAppStyles = true
        }
      }
    }
    .sensoryFeedback(.selection, trigger: self.selected)
    .sheet(isPresented: self.$showsAppStyles, onDismiss: self.reloadSelection) {
      NavigationStack {
        WritingStyleListView()
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button("Done") { self.showsAppStyles = false }
            }
          }
      }
    }
  }

  private static let sectionSpacing: CGFloat = 20

  @State private var selected = SharedSettings().defaultWritingStyle
  @State private var showsAppStyles = false

  private let canStyleApps = SharedSettings().canResolveHostApplication

  private func option(_ style: WritingStyle) -> some View {
    OnboardingOptionCard(
      title: LocalizedStringKey(style.displayNameKey),
      subtitle: LocalizedStringKey(style.descriptionKey),
      isSelected: self.selected == style,
      action: {
        self.selected = style
        SharedSettings().defaultWritingStyle = style
      },
      content: { StyleExampleBubble(style: style) },
    )
  }

  private func reloadSelection() {
    self.selected = SharedSettings().defaultWritingStyle
  }
}
