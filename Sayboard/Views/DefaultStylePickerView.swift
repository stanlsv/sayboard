import SwiftUI

// MARK: - DefaultStylePickerView

struct DefaultStylePickerView: View {

  // MARK: Internal

  @Binding var selectedStyle: WritingStyle

  var body: some View {
    VStack(spacing: 16) {
      Text(LocalizedStringKey("Default Style"))
        .font(.headline)
      self.cardList
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background {
      GeometryReader { geo in
        Color.clear.preference(
          key: SheetHeightKey.self,
          value: geo.size.height + geo.safeAreaInsets.bottom,
        )
      }
    }
    .background(Color(.systemGroupedBackground))
    .onPreferenceChange(SheetHeightKey.self) { self.sheetHeight = $0 }
    .presentationDragIndicator(.visible)
    .presentationBackground(Color(.systemGroupedBackground))
    .presentationDetents([.height(self.sheetHeight)])
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @State private var sheetHeight: CGFloat = 0

  private var cardList: some View {
    VStack(spacing: 12) {
      ForEach(WritingStyle.allCases, id: \.self) { style in
        let selected = self.selectedStyle == style
        Button {
          self.selectedStyle = style
          self.dismiss()
        } label: {
          StyleOptionRow(style: style, isSelected: selected)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .foregroundStyle(.primary)
      }
    }
  }
}

// MARK: - SheetHeightKey

struct SheetHeightKey: PreferenceKey {
  nonisolated(unsafe) static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
