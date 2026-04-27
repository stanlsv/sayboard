import Testing

@Suite("AppLanguageConfig.resolveLanguage")
struct AppLanguageConfigTests {

  @Test
  func `russian locale`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["ru-RU"])
    #expect(result == "ru")
  }

  @Test
  func `english US`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["en-US"])
    #expect(result == "en")
  }

  @Test
  func `english GB`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["en-GB"])
    #expect(result == "en")
  }

  @Test
  func `unsupported language falls back to english`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["sw-KE"])
    #expect(result == "en")
  }

  @Test
  func `empty array falls back to english`() {
    let result = AppLanguageConfig.resolveLanguage(from: [])
    #expect(result == "en")
  }

  @Test
  func `only first language is checked`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["sw-KE", "ru-RU"])
    #expect(result == "en")
  }

  @Test
  func `bare language code`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["ru"])
    #expect(result == "ru")
  }

  @Test
  func `japanese resolves to ja`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["ja-JP"])
    #expect(result == "ja")
  }

  @Test
  func `german resolves to de`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["de-DE"])
    #expect(result == "de")
  }

  @Test
  func `chinese simplified resolves to zh`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["zh-Hans-CN"])
    #expect(result == "zh")
  }

  @Test
  func `ukrainian resolves to uk`() {
    let result = AppLanguageConfig.resolveLanguage(from: ["uk-UA"])
    #expect(result == "uk")
  }
}
