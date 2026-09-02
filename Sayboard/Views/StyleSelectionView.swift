import SwiftUI

struct StyleSelectionView: View {

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
        StyleCard(style: style, isSelected: self.selectedStyle == style) {
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
        }
      }
    }
  }

}
