import SwiftUI

enum LanguagePickerMode {
  case single(Binding<String?>)
  case multi(Binding<Set<String>>)
}

struct LanguagePickerView: View {

  let mode: LanguagePickerMode
  var availableLanguages: Set<String> = SpeechLanguages.all
  var titleKey: LocalizedStringKey = "Languages"
  var allLanguagesKey: LocalizedStringKey = "All languages"
  var autoDetectKey: LocalizedStringKey = "Auto-detect (any language)"
  var footnoteKey: LocalizedStringKey?

  var body: some View {
    NavigationStack {
      List {
        Section {
          if self.searchText.isEmpty {
            self.headerRow
          }
          ForEach(self.filteredLanguages, id: \.self) { code in
            self.languageRow(code: code)
          }
        } header: {
          self.footnoteHeader
        }
      }
      .overlay {
        if !self.searchText.isEmpty, self.filteredLanguages.isEmpty {
          ContentUnavailableView.search(text: self.searchText)
        }
      }
      .searchable(text: self.$searchText, prompt: "Search languages")
      .navigationTitle(self.titleKey)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { self.dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @State private var searchText = ""

  private var sortedLanguages: [String] {
    self.availableLanguages.sorted { lhs, rhs in
      self.locale.capitalizedLanguageName(forLanguageCode: lhs)
        .localizedCompare(self.locale.capitalizedLanguageName(forLanguageCode: rhs)) == .orderedAscending
    }
  }

  private var filteredLanguages: [String] {
    if self.searchText.isEmpty {
      return self.sortedLanguages
    }
    let query = self.searchText.lowercased()
    return self.sortedLanguages.filter { code in
      let name = self.locale.capitalizedLanguageName(forLanguageCode: code).lowercased()
      return name.contains(query) || code.lowercased().contains(query)
    }
  }

  @ViewBuilder
  private var footnoteHeader: some View {
    if let footnoteKey = self.footnoteKey, self.searchText.isEmpty {
      Text(footnoteKey)
        .font(.callout)
        .foregroundStyle(.secondary)
        .textCase(nil)
        .padding(.bottom, 4)
    }
  }

  @ViewBuilder
  private var headerRow: some View {
    switch self.mode {
    case .single(let binding):
      self.headerRowContent(titleKey: self.allLanguagesKey, isChecked: binding.wrappedValue == nil) {
        binding.wrappedValue = nil
        self.dismiss()
      }

    case .multi(let binding):
      self.headerRowContent(titleKey: self.autoDetectKey, isChecked: binding.wrappedValue.isEmpty) {
        binding.wrappedValue = []
      }
    }
  }

  private func headerRowContent(
    titleKey: LocalizedStringKey,
    isChecked: Bool,
    action: @escaping () -> Void,
  ) -> some View {
    HStack {
      Text(titleKey)
      Spacer()
      if isChecked {
        Image(systemName: "checkmark")
          .foregroundStyle(Color.accentColor)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: action)
  }

  @ViewBuilder
  private func languageRow(code: String) -> some View {
    switch self.mode {
    case .single(let binding):
      self.languageRowContent(code: code, isChecked: binding.wrappedValue == code) {
        binding.wrappedValue = code
        self.dismiss()
      }

    case .multi(let binding):
      self.languageRowContent(code: code, isChecked: binding.wrappedValue.contains(code)) {
        var set = binding.wrappedValue
        if set.contains(code) {
          set.remove(code)
        } else {
          set.insert(code)
        }
        binding.wrappedValue = set
      }
    }
  }

  private func languageRowContent(
    code: String,
    isChecked: Bool,
    action: @escaping () -> Void,
  ) -> some View {
    HStack {
      Text(self.locale.capitalizedLanguageName(forLanguageCode: code))
      Spacer()
      if isChecked {
        Image(systemName: "checkmark")
          .foregroundStyle(Color.accentColor)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: action)
  }

}
