import Testing

@Suite("TextSanitizer")
struct TextSanitizerTests {

  @Test
  func whisperSpecialTokens() {
    let input = "Hello <|endoftext|> world <|startoftranscript|>"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func huggingFaceUnknownToken() {
    let input = "Hello <unk> world"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func squareBracketAnnotations() {
    let input = "Hello [Music] world [BLANK_AUDIO]"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func parenthesisAnnotations() {
    let input = "Hello (Applause) world (Laughter)"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func musicalNoteSymbols() {
    let input = "Hello \u{266A}\u{266B} world \u{2669}"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func unicodeReplacementCharacter() {
    let input = "Hello \u{FFFD} world"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func multipleArtifactTypes() {
    let input = "<|startoftranscript|> Hello <unk> [Music] \u{266A} world \u{FFFD} <|endoftext|>"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func emptyInput() {
    #expect(TextSanitizer.sanitize("").isEmpty)
  }

  @Test
  func allArtifactsReturnsEmpty() {
    let input = "<|endoftext|> [Music] \u{266A} <unk> \u{FFFD}"
    #expect(TextSanitizer.sanitize(input).isEmpty)
  }

  @Test
  func cleanTextPassthrough() {
    let input = "This is perfectly clean text."
    #expect(TextSanitizer.sanitize(input) == "This is perfectly clean text.")
  }

  @Test
  func whitespaceNormalization() {
    let input = "  Hello   world  "
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func whitespaceAfterArtifactRemoval() {
    let input = "Hello  [Music]  world"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }

  @Test
  func allMusicalNoteVariants() {
    let allNotes = "\u{2669}\u{266A}\u{266B}\u{266C}\u{266D}\u{266E}\u{266F}"
    #expect(TextSanitizer.sanitize(allNotes).isEmpty)
  }

  @Test
  func multiWordBracketAnnotation() {
    let input = "Hello [background noise] world"
    #expect(TextSanitizer.sanitize(input) == "Hello world")
  }
}
