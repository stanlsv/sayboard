import SwiftUI

// MARK: - StyleSelectionView

struct StyleSelectionView: View {

  // MARK: Lifecycle

  init(
    appName: String,
    bundleId: String,
    iconURL: URL? = nil,
    currentStyle: WritingStyle? = nil,
    onStyleChanged: @escaping () -> Void = { },
  ) {
    self.appName = appName
    self.bundleId = bundleId
    self.iconURL = iconURL
    self.onStyleChanged = onStyleChanged
    _selectedStyle = State(initialValue: currentStyle)
  }

  // MARK: Internal

  var body: some View {
    VStack(spacing: 16) {
      Text(verbatim: self.appName)
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

  @State private var selectedStyle: WritingStyle?
  @State private var sheetHeight: CGFloat = 0
  @Environment(\.dismiss) private var dismiss

  private let appName: String
  private let bundleId: String
  private let iconURL: URL?
  private let store = AppStyleStore()
  private let onStyleChanged: () -> Void

  private var cardList: some View {
    VStack(spacing: 12) {
      ForEach(WritingStyle.allCases, id: \.self) { style in
        let selected = self.selectedStyle == style
        Button {
          self.selectedStyle = style
          let entry = AppStyleEntry(
            bundleId: self.bundleId,
            name: self.appName,
            iconURL: self.iconURL,
            style: style,
          )
          self.store.addEntry(entry)
          self.onStyleChanged()
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
