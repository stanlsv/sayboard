import Foundation
import Testing

@Suite("SnippetExpander")
struct SnippetExpanderTests {

  @Test
  func emptySnippetsReturnsOriginal() {
    let text = "hello world"
    let result = SnippetExpander.expand(text, snippets: [])
    #expect(result == text)
  }

  @Test
  func singleTriggerMatch() {
    let snippets = [Snippet(trigger: "my email", replacement: "test@example.com")]
    let result = SnippetExpander.expand("send to my email please", snippets: snippets)
    #expect(result == "send to test@example.com please")
  }

  @Test
  func caseInsensitiveMatch() {
    let snippets = [Snippet(trigger: "my email", replacement: "test@example.com")]
    let result = SnippetExpander.expand("send to My Email please", snippets: snippets)
    #expect(result == "send to test@example.com please")
  }

  @Test
  func wordBoundaryRespected() {
    let snippets = [Snippet(trigger: "cat", replacement: "dog")]
    let result = SnippetExpander.expand("the category of cat is clear", snippets: snippets)
    #expect(result == "the category of dog is clear")
  }

  @Test
  func multipleNonOverlappingMatches() {
    let snippets = [
      Snippet(trigger: "my email", replacement: "test@example.com"),
      Snippet(trigger: "my phone", replacement: "555-1234"),
    ]
    let result = SnippetExpander.expand("contact my email or my phone", snippets: snippets)
    #expect(result == "contact test@example.com or 555-1234")
  }

  @Test
  func longestMatchWins() {
    let snippets = [
      Snippet(trigger: "my channel", replacement: "https://short.url"),
      Snippet(trigger: "my YouTube channel", replacement: "https://youtube.com/@channel"),
    ]
    let result = SnippetExpander.expand("check out my YouTube channel today", snippets: snippets)
    #expect(result == "check out https://youtube.com/@channel today")
  }

  @Test
  func disabledSnippetSkipped() {
    let snippets = [Snippet(trigger: "my email", replacement: "test@example.com", isEnabled: false)]
    let result = SnippetExpander.expand("send to my email please", snippets: snippets)
    #expect(result == "send to my email please")
  }

  @Test
  func specialCharactersInTrigger() {
    let snippets = [Snippet(trigger: "c++", replacement: "C Plus Plus")]
    let result = SnippetExpander.expand("I code in c++ daily", snippets: snippets)
    #expect(result == "I code in C Plus Plus daily")
  }

  @Test
  func regexMetacharactersInTrigger() {
    let snippets = [Snippet(trigger: "price (USD)", replacement: "$100")]
    let result = SnippetExpander.expand("the price (USD) is shown", snippets: snippets)
    #expect(result == "the $100 is shown")
  }

  @Test
  func specialCharactersInReplacement() {
    let snippets = [Snippet(trigger: "price", replacement: "$100\\each")]
    let result = SnippetExpander.expand("the price is fair", snippets: snippets)
    #expect(result == "the $100\\each is fair")
  }

  @Test
  func multipleOccurrencesOfSameTrigger() {
    let snippets = [Snippet(trigger: "btw", replacement: "by the way")]
    let result = SnippetExpander.expand("btw I think btw it works", snippets: snippets)
    #expect(result == "by the way I think by the way it works")
  }

  @Test
  func codableRoundTrip() throws {
    let original = Snippet(trigger: "my email", replacement: "test@example.com", isEnabled: false)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(Snippet.self, from: data)
    #expect(decoded == original)
  }

  @Test
  func emptyTriggerIsNoOp() {
    let snippets = [Snippet(trigger: "", replacement: "something")]
    let result = SnippetExpander.expand("hello world", snippets: snippets)
    #expect(result == "hello world")
  }

  @Test
  func whitespaceTriggerIsNoOp() {
    let snippets = [Snippet(trigger: "   ", replacement: "something")]
    let result = SnippetExpander.expand("hello world", snippets: snippets)
    #expect(result == "hello world")
  }

  @Test
  func noMatchReturnsOriginal() {
    let snippets = [Snippet(trigger: "xyz", replacement: "abc")]
    let result = SnippetExpander.expand("hello world", snippets: snippets)
    #expect(result == "hello world")
  }

  @Test
  func triggerAtStartOfText() {
    let snippets = [Snippet(trigger: "hello", replacement: "hi")]
    let result = SnippetExpander.expand("hello world", snippets: snippets)
    #expect(result == "hi world")
  }

  @Test
  func triggerAtEndOfText() {
    let snippets = [Snippet(trigger: "world", replacement: "earth")]
    let result = SnippetExpander.expand("hello world", snippets: snippets)
    #expect(result == "hello earth")
  }
}
