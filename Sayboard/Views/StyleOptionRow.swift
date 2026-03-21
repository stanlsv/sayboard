import SwiftUI

// MARK: - StyleOptionRow

struct StyleOptionRow: View {

  // MARK: Internal

  let style: WritingStyle
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(LocalizedStringKey(self.style.displayNameKey))
            .font(.headline)
          Text(LocalizedStringKey(self.style.descriptionKey))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        Image(systemName: self.isSelected ? "circle.inset.filled" : "circle")
          .font(.title2)
          .foregroundStyle(self.isSelected ? Color.accentColor : .secondary)
      }
      HStack(alignment: .center, spacing: 10) {
        Text(LocalizedStringKey("AvatarLetter"))
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white)
          .frame(width: 28, height: 28)
          .background(self.avatarColor)
          .clipShape(Circle())
        Text(LocalizedStringKey(self.style.exampleKey))
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.leading)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.tertiarySystemGroupedBackground))
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .contentShape(Rectangle())
  }

  // MARK: Private

  private var avatarColor: Color {
    switch self.style {
    case .formal: Color(red: 0.68, green: 0.58, blue: 0.50)
    case .casual: Color(red: 0.64, green: 0.56, blue: 0.60)
    case .veryCasual: Color(red: 0.55, green: 0.60, blue: 0.58)
    }
  }
}
