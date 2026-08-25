import SwiftUI

struct InterfaceLanguage: Identifiable {
  let code: String
  let englishName: String
  let nativeName: String

  var id: String {
    self.code
  }
}

struct AppLanguageListView: View {

  var body: some View {
    List {
      ForEach(Self.interfaceLanguages) { lang in
        Button {
          guard lang.code != self.selectedAppLanguage else {
            self.dismiss()
            return
          }
          NotificationCenter.default.post(name: .appLanguageChangeRequested, object: lang.code)
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(verbatim: lang.englishName)
              Text(verbatim: lang.nativeName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if self.selectedAppLanguage == lang.code {
              Image(systemName: "checkmark")
                .foregroundStyle(Color.accentColor)
                .fontWeight(.semibold)
            }
          }
        }
        .foregroundStyle(.primary)
      }
    }
    .navigationTitle("App Language")
    .navigationBarTitleDisplayMode(.inline)
  }

  private static let interfaceLanguages: [InterfaceLanguage] = [
    InterfaceLanguage(code: "en", englishName: "English", nativeName: "English"),
    InterfaceLanguage(code: "bg", englishName: "Bulgarian", nativeName: "Български"),
    InterfaceLanguage(code: "cs", englishName: "Czech", nativeName: "Čeština"),
    InterfaceLanguage(code: "da", englishName: "Danish", nativeName: "Dansk"),
    InterfaceLanguage(code: "de", englishName: "German", nativeName: "Deutsch"),
    InterfaceLanguage(code: "el", englishName: "Greek", nativeName: "Ελληνικά"),
    InterfaceLanguage(code: "es", englishName: "Spanish", nativeName: "Español"),
    InterfaceLanguage(code: "et", englishName: "Estonian", nativeName: "Eesti"),
    InterfaceLanguage(code: "fi", englishName: "Finnish", nativeName: "Suomi"),
    InterfaceLanguage(code: "fr", englishName: "French", nativeName: "Français"),
    InterfaceLanguage(code: "hi", englishName: "Hindi", nativeName: "हिन्दी"),
    InterfaceLanguage(code: "hr", englishName: "Croatian", nativeName: "Hrvatski"),
    InterfaceLanguage(code: "hu", englishName: "Hungarian", nativeName: "Magyar"),
    InterfaceLanguage(code: "it", englishName: "Italian", nativeName: "Italiano"),
    InterfaceLanguage(code: "ja", englishName: "Japanese", nativeName: "日本語"),
    InterfaceLanguage(code: "ko", englishName: "Korean", nativeName: "한국어"),
    InterfaceLanguage(code: "lt", englishName: "Lithuanian", nativeName: "Lietuvių"),
    InterfaceLanguage(code: "lv", englishName: "Latvian", nativeName: "Latviešu"),
    InterfaceLanguage(code: "nl", englishName: "Dutch", nativeName: "Nederlands"),
    InterfaceLanguage(code: "no", englishName: "Norwegian", nativeName: "Norsk"),
    InterfaceLanguage(code: "pl", englishName: "Polish", nativeName: "Polski"),
    InterfaceLanguage(code: "pt", englishName: "Portuguese", nativeName: "Português"),
    InterfaceLanguage(code: "ro", englishName: "Romanian", nativeName: "Română"),
    InterfaceLanguage(code: "ru", englishName: "Russian", nativeName: "Русский"),
    InterfaceLanguage(code: "sk", englishName: "Slovak", nativeName: "Slovenčina"),
    InterfaceLanguage(code: "sl", englishName: "Slovenian", nativeName: "Slovenščina"),
    InterfaceLanguage(code: "sv", englishName: "Swedish", nativeName: "Svenska"),
    InterfaceLanguage(code: "tr", englishName: "Turkish", nativeName: "Türkçe"),
    InterfaceLanguage(code: "uk", englishName: "Ukrainian", nativeName: "Українська"),
    InterfaceLanguage(code: "zh", englishName: "Chinese", nativeName: "中文"),
  ]

  private static let defaultLanguage = AppLanguageConfig.fallback

  @AppStorage(SharedKey.appLanguage) private var selectedAppLanguage = defaultLanguage
  @Environment(\.dismiss) private var dismiss
}

let nativeLanguageNames: [String: String] = [
  "en": "English",
  "bg": "Български",
  "cs": "Čeština",
  "da": "Dansk",
  "de": "Deutsch",
  "el": "Ελληνικά",
  "es": "Español",
  "et": "Eesti",
  "fi": "Suomi",
  "fr": "Français",
  "hi": "हिन्दी",
  "hr": "Hrvatski",
  "hu": "Magyar",
  "it": "Italiano",
  "ja": "日本語",
  "ko": "한국어",
  "lt": "Lietuvių",
  "lv": "Latviešu",
  "nl": "Nederlands",
  "no": "Norsk",
  "pl": "Polski",
  "pt": "Português",
  "ro": "Română",
  "ru": "Русский",
  "sk": "Slovenčina",
  "sl": "Slovenščina",
  "sv": "Svenska",
  "tr": "Türkçe",
  "uk": "Українська",
  "zh": "中文",
]
