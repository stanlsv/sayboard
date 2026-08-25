import SwiftUI

struct DefaultStylePickerView: View {

  @Binding var selectedStyle: WritingStyle

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        Text(self.title)
          .font(.title3.weight(.semibold))
          .padding(.top, 8)
        self.cardList
        if !self.archivedEntries.isEmpty {
          self.archiveSection
        }
      }
      .padding(.vertical)
      .padding(.horizontal, Self.horizontalPadding)
      .frame(maxWidth: .infinity)
      .background {
        GeometryReader { geo in
          Color.clear.preference(
            key: SheetHeightKey.self,
            value: geo.size.height + geo.safeAreaInsets.bottom,
          )
        }
      }
    }
    .scrollBounceBehavior(.basedOnSize)
    .background(Color(.systemGroupedBackground))
    .onPreferenceChange(SheetHeightKey.self) { self.sheetHeight = $0 }
    .onAppear { self.loadArchivedEntries() }
    .presentationDragIndicator(.visible)
    .presentationBackground(Color(.systemGroupedBackground))
    .presentationDetents([.height(self.sheetHeight)])
  }

  private static let cardCornerRadius: CGFloat = 12
  private static let horizontalPadding: CGFloat = 20

  private static let groupCornerRadius: CGFloat = 26
  private static let rowInset: CGFloat = 16
  private static let rowMinHeight: CGFloat = 52
  private static let iconSize: CGFloat = 29
  private static let iconCornerRadius: CGFloat = 6.5
  private static let iconTextGap: CGFloat = 16

  @Environment(\.dismiss) private var dismiss
  @State private var sheetHeight: CGFloat = 0
  @State private var archivedEntries = [AppStyleEntry]()

  private let store = AppStyleStore()

  private var title: LocalizedStringKey {
    OperatingSystem.isHostBundleIdBroken ? "Writing Style" : "Default Style"
  }

  private var cardList: some View {
    VStack(spacing: 12) {
      ForEach(WritingStyle.allCases, id: \.self) { style in
        self.styleCard(for: style)
      }
    }
  }

  private var archiveSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Configured earlier")
        .font(.headline)
        .padding(.leading, Self.rowInset)

      self.archivedAppsCard

      Text("Since iOS 26.4, keyboards can no longer identify the app you are typing in, so these settings no longer apply.")
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Self.rowInset)
    }
  }

  private var archivedAppsCard: some View {
    VStack(spacing: 0) {
      ForEach(self.archivedEntries) { entry in
        HStack(spacing: Self.iconTextGap) {
          self.appIcon(url: entry.iconURL)
          Text(verbatim: entry.name)
            .lineLimit(1)
          Spacer()
        }
        .padding(.horizontal, Self.rowInset)
        .frame(minHeight: Self.rowMinHeight)

        Divider()
          .padding(.leading, Self.rowInset + Self.iconSize + Self.iconTextGap)
          .padding(.trailing, Self.rowInset)
      }

      Button(role: .destructive) {
        self.deleteArchivedEntries()
      } label: {
        HStack {
          Text("Delete All")
          Spacer()
        }
        .padding(.horizontal, Self.rowInset)
        .frame(minHeight: Self.rowMinHeight)
        .contentShape(Rectangle())
      }
    }
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: Self.groupCornerRadius, style: .continuous))
  }

  private func styleCard(for style: WritingStyle) -> some View {
    let selected = self.selectedStyle == style
    return Button {
      self.selectedStyle = style
      self.dismiss()
    } label: {
      StyleOptionRow(style: style, isSelected: selected)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius))
        .overlay(
          RoundedRectangle(cornerRadius: Self.cardCornerRadius)
            .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
    .foregroundStyle(.primary)
  }

  private func appIcon(url: URL?) -> some View {
    AsyncImage(url: url) { image in
      image
        .resizable()
        .aspectRatio(contentMode: .fill)
    } placeholder: {
      RoundedRectangle(cornerRadius: Self.iconCornerRadius, style: .continuous)
        .fill(.quaternary)
    }
    .frame(width: Self.iconSize, height: Self.iconSize)
    .clipShape(RoundedRectangle(cornerRadius: Self.iconCornerRadius, style: .continuous))
  }

  private func loadArchivedEntries() {
    guard OperatingSystem.isHostBundleIdBroken else { return }
    self.archivedEntries = self.store.loadEntries()
  }

  private func deleteArchivedEntries() {
    self.store.saveEntries([])
    withAnimation { self.archivedEntries = [] }
  }
}

struct SheetHeightKey: PreferenceKey {
  nonisolated(unsafe) static var defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
