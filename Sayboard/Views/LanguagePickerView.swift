import SwiftUI

// MARK: - LanguagePickerView

struct LanguagePickerView: View {

  // MARK: Internal

  @Binding var selectedLanguage: String?

  var availableLanguages: Set<String> = SpeechLanguages.all

  var body: some View {
    NavigationStack {
      List {
        if self.searchText.isEmpty {
          self.allLanguagesRow
        }
        ForEach(self.filteredLanguages, id: \.self) { code in
          self.languageRow(code: code)
        }
      }
      .overlay {
        if !self.searchText.isEmpty, self.filteredLanguages.isEmpty {
          ContentUnavailableView.search(text: self.searchText)
        }
      }
      .searchable(text: self.$searchText, prompt: "Search languages")
      .navigationTitle("Languages")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { self.dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  // MARK: Private

  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @State private var searchText = ""

  private var sortedLanguages: [String] {
    self.availableLanguages.sorted { lhs, rhs in
      self.languageName(for: lhs)
        .localizedCompare(self.languageName(for: rhs)) == .orderedAscending
    }
  }

  private var filteredLanguages: [String] {
    if self.searchText.isEmpty {
      return self.sortedLanguages
    }
    let query = self.searchText.lowercased()
    return self.sortedLanguages.filter { code in
      let name = self.languageName(for: code).lowercased()
      return name.contains(query) || code.lowercased().contains(query)
    }
  }

  private var allLanguagesRow: some View {
    HStack {
      Text("All languages")
      Spacer()
      if self.selectedLanguage == nil {
        Image(systemName: "checkmark")
          .foregroundStyle(Color.accentColor)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      self.selectedLanguage = nil
      self.dismiss()
    }
  }

  private func languageRow(code: String) -> some View {
    HStack {
      Text(self.languageName(for: code))
      Spacer()
      if self.selectedLanguage == code {
        Image(systemName: "checkmark")
          .foregroundStyle(Color.accentColor)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      self.selectedLanguage = code
      self.dismiss()
    }
  }

  private func languageName(for code: String) -> String {
    guard let name = self.locale.localizedString(forLanguageCode: code) else {
      return code
    }
    return name.prefix(1).uppercased() + name.dropFirst()
  }
}
