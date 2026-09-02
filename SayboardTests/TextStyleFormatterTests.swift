import Foundation
import Testing

@Suite("Very Casual leaves literals alone")
struct VeryCasualLiteralTests {

  @Test
  func `a url keeps its scheme separator and its case`() {
    let result = TextStyleFormatter.format("Open https://X.com/AbC now.", style: .veryCasual)
    #expect(result.contains("https://X.com/AbC"))
  }

  @Test
  func `a bare www address survives`() {
    #expect(TextStyleFormatter.format("see www.example.com ok", style: .veryCasual).contains("www.example.com"))
  }

  @Test
  func `a clock time keeps its colon`() {
    #expect(TextStyleFormatter.format("Meet at 14:30, please.", style: .veryCasual).contains("14:30"))
  }

  @Test
  func `a time written with a fullwidth colon keeps its separator`() {
    #expect(TextStyleFormatter.format("集合は14：30です。", style: .veryCasual).contains("14：30"))
  }

  @Test
  func `a time written with fullwidth digits keeps its separator`() {
    #expect(TextStyleFormatter.format("集合は１４：３０です。", style: .veryCasual).contains("１４：３０"))
  }

  @Test
  func `a decimal number keeps its separator`() {
    #expect(TextStyleFormatter.format("It weighs 3.5 kilos.", style: .veryCasual).contains("3.5"))
  }

  @Test
  func `an email address keeps its dot`() {
    #expect(TextStyleFormatter.format("write to a.b@example.com ok", style: .veryCasual).contains("a.b@example.com"))
  }
}

@Suite("Very Casual still strips prose")
struct VeryCasualProseTests {

  @Test
  func `prose loses its capitals and punctuation`() {
    #expect(TextStyleFormatter.format("Wait, He said: yes; ok.", style: .veryCasual) == "wait he said yes ok")
  }

  @Test
  func `a sentence period after a number is still removed`() {
    #expect(TextStyleFormatter.format("It costs 4200. Later.", style: .veryCasual) == "it costs 4200 later")
  }

  @Test
  func `text around a protected span is still stripped`() {
    let result = TextStyleFormatter.format("Call Me At 14:30, Please.", style: .veryCasual)
    #expect(result == "call me at 14:30 please")
  }

  @Test
  func `runs of spaces collapse to one`() {
    #expect(TextStyleFormatter.format("a,  b,  c", style: .veryCasual) == "a b c")
  }

  @Test
  func `each line is trimmed`() {
    #expect(TextStyleFormatter.format("A.\n  B.  ", style: .veryCasual) == "a\nb")
  }
}

@Suite("Formal and Casual are unchanged")
struct OtherStyleTests {

  @Test
  func `formal passes text through untouched`() {
    let text = "Wait, did you see that? He can't believe it happened."
    #expect(TextStyleFormatter.format(text, style: .formal) == text)
  }

  @Test
  func `casual drops only the trailing period`() {
    #expect(TextStyleFormatter.format("Wait, did you see that.", style: .casual) == "Wait, did you see that")
  }

  @Test
  func `casual keeps a url intact`() {
    #expect(TextStyleFormatter.format("go to https://x.com/A", style: .casual) == "go to https://x.com/A")
  }
}

@Suite("Reading a stored WritingStyle")
struct StoredStyleTests {

  @Test
  func `current raw values read back as themselves`() {
    for style in WritingStyle.allCases {
      #expect(WritingStyle(stored: style.rawValue) == style)
    }
  }

  @Test
  func `the old informal label becomes casual`() {
    #expect(WritingStyle(stored: "informal") == .casual)
  }

  @Test
  func `the old official label becomes formal, not its opposite`() {
    #expect(WritingStyle(stored: "official") == .formal)
  }

  @Test
  func `an unknown value is rejected rather than guessed`() {
    #expect(WritingStyle(stored: "sarcastic") == nil)
  }

  @Test
  func `decoding agrees with the plain-string path for every value either can see`() {
    for raw in Self.everyStoredValue {
      let decoded = try? JSONDecoder().decode(WritingStyle.self, from: Data("\"\(raw)\"".utf8))
      #expect(decoded == WritingStyle(stored: raw), "paths disagree on \(raw)")
    }
  }

  @Test
  func `decoding an unknown value throws`() {
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(WritingStyle.self, from: Data("\"sarcastic\"".utf8))
    }
  }

  private static let everyStoredValue =
    WritingStyle.allCases.map(\.rawValue) + ["informal", "official"]
}
