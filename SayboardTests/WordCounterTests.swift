import Testing
@testable import Sayboard

@Suite("Counting dictated words")
struct WordCounterTests {

  @Test
  func `an English sentence counts its words`() {
    #expect(WordCounter.count("The weather is great today, let's go for a walk in the park.") == 13)
  }

  @Test
  func `a Russian sentence counts its words`() {
    #expect(WordCounter.count("Сегодня отличная погода, пойдём гулять в парк.") == 7)
  }

  @Test
  func `a Chinese sentence counts as several words, not one`() {
    #expect(WordCounter.count("今天天气很好，我们去公园散步吧。") > 1)
  }

  @Test
  func `a Japanese sentence counts as several words, not one`() {
    #expect(WordCounter.count("今日はとても良い天気なので、公園に散歩に行きます。") > 1)
  }

  @Test
  func `empty and blank text costs nothing`() {
    #expect(WordCounter.count("") == 0)
    #expect(WordCounter.count("   \n\t") == 0)
  }

  @Test
  func `punctuation alone costs nothing`() {
    #expect(WordCounter.count("...!?") == 0)
  }
}
