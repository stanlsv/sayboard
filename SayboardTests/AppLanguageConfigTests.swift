import Testing

@Suite("AppLanguageConfig.resolveLanguage")
struct AppLanguageConfigTests {

  @Test
  func russianLocale() {
    let result = AppLanguageConfig.resolveLanguage(from: ["ru-RU"])
    #expect(result == "ru")
  }

  @Test
  func englishUS() {
    let result = AppLanguageConfig.resolveLanguage(from: ["en-US"])
    #expect(result == "en")
  }

  @Test
  func englishGB() {
    let result = AppLanguageConfig.resolveLanguage(from: ["en-GB"])
    #expect(result == "en")
  }

  @Test
  func unsupportedLanguageFallsBackToEnglish() {
    let result = AppLanguageConfig.resolveLanguage(from: ["sw-KE"])
    #expect(result == "en")
  }

  @Test
  func emptyArrayFallsBackToEnglish() {
    let result = AppLanguageConfig.resolveLanguage(from: [])
    #expect(result == "en")
  }

  @Test
  func onlyFirstLanguageIsChecked() {
    let result = AppLanguageConfig.resolveLanguage(from: ["sw-KE", "ru-RU"])
    #expect(result == "en")
  }

  @Test
  func bareLanguageCode() {
    let result = AppLanguageConfig.resolveLanguage(from: ["ru"])
    #expect(result == "ru")
  }

  @Test
  func japaneseResolvesToJa() {
    let result = AppLanguageConfig.resolveLanguage(from: ["ja-JP"])
    #expect(result == "ja")
  }

  @Test
  func germanResolvesToDe() {
    let result = AppLanguageConfig.resolveLanguage(from: ["de-DE"])
    #expect(result == "de")
  }

  @Test
  func chineseSimplifiedResolvesToZh() {
    let result = AppLanguageConfig.resolveLanguage(from: ["zh-Hans-CN"])
    #expect(result == "zh")
  }

  @Test
  func ukrainianResolvesToUk() {
    let result = AppLanguageConfig.resolveLanguage(from: ["uk-UA"])
    #expect(result == "uk")
  }
}
