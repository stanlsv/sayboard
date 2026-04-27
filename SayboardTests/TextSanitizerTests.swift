import Testing

@Suite("TextSanitizer")
struct TextSanitizerTests {

  @Test
  func `whisper special tokens`() {
    let input = "Hello <|endoftext|> world <|startoftranscript|>"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func `hugging face unknown token`() {
    let input = "Hello <unk> world"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func `square bracket annotations`() {
    let input = "Hello [Music] world [BLANK_AUDIO]"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func `parenthesis annotations`() {
    let input = "Hello (Applause) world (Laughter)"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func `musical note symbols`() {
    let input = "Hello \u{266A}\u{266B} world \u{2669}"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func `unicode replacement character`() {
    let input = "Hello \u{FFFD} world"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func `multiple artifact types`() {
    let input = "<|startoftranscript|> Hello <unk> [Music] \u{266A} world \u{FFFD} <|endoftext|>"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func `empty input`() {
    #expect(TextSanitizer.sanitize("").isEmpty)
  }

  @Test
  func `all artifacts returns empty`() {
    let input = "<|endoftext|> [Music] \u{266A} <unk> \u{FFFD}"
    #expect(TextSanitizer.sanitize(input).isEmpty)
  }

  @Test
  func `clean text passthrough`() {
    let input = "This is perfectly clean text."
    #expect(TextSanitizer.sanitize(input) == "This is perfectly clean text.")
  }

  @Test
  func `whitespace normalization`() {
    let input = "  Hello   world  "
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func `whitespace after artifact removal`() {
    let input = "Hello  [Music]  world"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func `all musical note variants`() {
    let allNotes = "\u{2669}\u{266A}\u{266B}\u{266C}\u{266D}\u{266E}\u{266F}"
    #expect(TextSanitizer.sanitize(allNotes).isEmpty)
  }

  @Test
  func `multi word bracket annotation`() {
    let input = "Hello [background noise] world"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }
}
