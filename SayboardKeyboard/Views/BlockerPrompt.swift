import SwiftUI

struct BlockerPrompt: View {

  let blocker: SetupBlocker

  var body: some View {
    VStack(spacing: 12.kbScaled) {
      Image(systemName: self.blocker.icon)
        .font(.system(size: Self.promptIconSize))
        .foregroundStyle(.blue)

      Text(self.blocker.message)
        .font(.subheadline.weight(.semibold))
        .multilineTextAlignment(.center)
        .padding(.horizontal, Self.promptHorizontalPadding)

      if let url = self.blocker.linkURL {
        Link(destination: url) {
          Text(self.blocker.buttonTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20.kbScaled)
            .frame(minHeight: Self.capsuleHeight)
            .background(.blue, in: Capsule())
        }
        .padding(.horizontal, Self.promptHorizontalPadding)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private static var promptIconSize: CGFloat {
    40.kbScaled
  }

  private static var promptHorizontalPadding: CGFloat {
    32.kbScaled
  }

  private static var capsuleHeight: CGFloat {
    40.kbScaled
  }
}
