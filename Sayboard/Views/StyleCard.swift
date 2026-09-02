import SwiftUI

struct StyleCard: View {

  let style: WritingStyle
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: self.onTap) {
      StyleOptionRow(style: self.style, isSelected: self.isSelected)
        .padding(Self.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        .overlay(
          RoundedRectangle(cornerRadius: Self.cornerRadius)
            .strokeBorder(self.isSelected ? Color.accentColor : .clear, lineWidth: Self.strokeWidth)
        )
    }
    .foregroundStyle(.primary)
  }

  private static let contentPadding: CGFloat = 12
  private static let cornerRadius: CGFloat = 12
  private static let strokeWidth: CGFloat = 2
}
