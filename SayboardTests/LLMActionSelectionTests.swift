import Foundation
import Testing

@Suite("LLMActionSelection")
struct LLMActionSelectionTests {

  // MARK: Internal

  @Test
  func `codable round trip none`() throws {
    let original = LLMActionSelection.none
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LLMActionSelection.self, from: data)
    #expect(decoded == original)
  }

  @Test
  func `codable round trip preset`() throws {
    let original = LLMActionSelection.preset(.formal)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LLMActionSelection.self, from: data)
    #expect(decoded == original)
  }

  @Test
  func `codable round trip custom prompt`() throws {
    let id = UUID()
    let original = LLMActionSelection.customPrompt(id)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LLMActionSelection.self, from: data)
    #expect(decoded == original)
  }

  @Test
  func `is set none`() {
    #expect(!LLMActionSelection.none.isSet)
  }

  @Test
  func `is set preset`() {
    #expect(LLMActionSelection.preset(.rewrite).isSet)
  }

  @Test
  func `is set custom prompt`() {
    #expect(LLMActionSelection.customPrompt(UUID()).isSet)
  }

  @Test
  func `resolve none`() {
    let result = LLMActionSelection.none.resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
    )
    #expect(result == nil)
  }

  @Test
  func `resolve preset`() {
    let result = LLMActionSelection.preset(.formal).resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
    )
    #expect(result?.action == .formal)
    #expect(result?.customPromptId == nil)
  }

  @Test
  func `resolve valid custom prompt`() {
    let result = LLMActionSelection.customPrompt(Self.testPromptId).resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
    )
    #expect(result?.action == .rewrite)
    #expect(result?.customPromptId == Self.testPromptId)
  }

  @Test
  func `resolve invalid custom prompt`() {
    let result = LLMActionSelection.customPrompt(Self.missingPromptId).resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
    )
    #expect(result == nil)
  }

  @Test
  func `all options count`() {
    let expectedCount = 1 + LLMAction.allCases.count + Self.testPrompts.count
    let options = LLMActionSelection.allOptions(customPrompts: Self.testPrompts)
    #expect(options.count == expectedCount)
  }

  @Test
  func `all options starts with none`() {
    let options = LLMActionSelection.allOptions(customPrompts: Self.testPrompts)
    #expect(options.first == LLMActionSelection.none)
  }

  @Test
  func `all options empty prompts`() {
    let expectedCount = 1 + LLMAction.allCases.count
    let options = LLMActionSelection.allOptions(customPrompts: [])
    #expect(options.count == expectedCount)
  }

  @Test
  func `display name preset`() {
    let name = LLMActionSelection.preset(.formal).displayName(customPrompts: Self.testPrompts)
    #expect(!name.isEmpty)
  }

  @Test
  func `display name valid custom prompt`() {
    let name = LLMActionSelection.customPrompt(Self.testPromptId)
      .displayName(customPrompts: Self.testPrompts)
    #expect(name == "Summarize")
  }

  @Test
  func `display name invalid custom prompt falls back`() {
    let name = LLMActionSelection.customPrompt(Self.missingPromptId)
      .displayName(customPrompts: Self.testPrompts)
    #expect(!name.isEmpty)
  }

  @Test
  func `enabled actions excluding none`() {
    let result = LLMAction.enabledActions(excluding: [])
    #expect(result == LLMAction.allCases)
  }

  @Test
  func `enabled actions excluding some`() {
    let disabled: Set<LLMAction> = [.formal, .casual]
    let result = LLMAction.enabledActions(excluding: disabled)
    #expect(result == [
      .removeRedundancy,
      .rewrite,
      .fixGrammar,
      .simplify,
      .continueWriting,
      .shorten,
      .bulletPoints,
      .summarize,
      .expand,
      .addPunctuation,
    ])
  }

  @Test
  func `enabled actions excluding all`() {
    let disabled = Set(LLMAction.allCases)
    let result = LLMAction.enabledActions(excluding: disabled)
    #expect(result.isEmpty)
  }

  @Test
  func `all options with disabled actions`() {
    let disabled: Set<LLMAction> = [.formal, .casual]
    let enabledPresetCount = LLMAction.allCases.count - disabled.count
    let expectedCount = 1 + enabledPresetCount + Self.testPrompts.count
    let options = LLMActionSelection.allOptions(
      customPrompts: Self.testPrompts,
      disabledActions: disabled,
    )
    #expect(options.count == expectedCount)
  }

  @Test
  func `resolve preset disabled`() {
    let result = LLMActionSelection.preset(.formal).resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
      disabledActions: [.formal],
    )
    #expect(result == nil)
  }

  @Test
  func `resolve preset not disabled`() {
    let result = LLMActionSelection.preset(.formal).resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
      disabledActions: [.casual],
    )
    #expect(result?.action == .formal)
    #expect(result?.customPromptId == nil)
  }

  // MARK: Private

  private static let testPromptId = UUID()
  private static let missingPromptId = UUID()
  private static let testPrompts = [
    LLMCustomPrompt(id: testPromptId, name: "Summarize", prompt: "Summarize the text")
  ]

}
