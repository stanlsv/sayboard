import Foundation
import Testing

@Suite("LLMActionSelection")
struct LLMActionSelectionTests {

  // MARK: Internal

  @Test
  func codableRoundTripNone() throws {
    let original = LLMActionSelection.none
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LLMActionSelection.self, from: data)
    #expect(decoded == original)
  }

  @Test
  func codableRoundTripPreset() throws {
    let original = LLMActionSelection.preset(.formal)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LLMActionSelection.self, from: data)
    #expect(decoded == original)
  }

  @Test
  func codableRoundTripCustomPrompt() throws {
    let id = UUID()
    let original = LLMActionSelection.customPrompt(id)
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(LLMActionSelection.self, from: data)
    #expect(decoded == original)
  }

  @Test
  func isSetNone() {
    #expect(!LLMActionSelection.none.isSet)
  }

  @Test
  func isSetPreset() {
    #expect(LLMActionSelection.preset(.rewrite).isSet)
  }

  @Test
  func isSetCustomPrompt() {
    #expect(LLMActionSelection.customPrompt(UUID()).isSet)
  }

  @Test
  func resolveNone() {
    let result = LLMActionSelection.none.resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
    )
    #expect(result == nil)
  }

  @Test
  func resolvePreset() {
    let result = LLMActionSelection.preset(.formal).resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
    )
    #expect(result?.action == .formal)
    #expect(result?.customPromptId == nil)
  }

  @Test
  func resolveValidCustomPrompt() {
    let result = LLMActionSelection.customPrompt(Self.testPromptId).resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
    )
    #expect(result?.action == .rewrite)
    #expect(result?.customPromptId == Self.testPromptId)
  }

  @Test
  func resolveInvalidCustomPrompt() {
    let result = LLMActionSelection.customPrompt(Self.missingPromptId).resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
    )
    #expect(result == nil)
  }

  @Test
  func allOptionsCount() {
    let expectedCount = 1 + LLMAction.allCases.count + Self.testPrompts.count
    let options = LLMActionSelection.allOptions(customPrompts: Self.testPrompts)
    #expect(options.count == expectedCount)
  }

  @Test
  func allOptionsStartsWithNone() {
    let options = LLMActionSelection.allOptions(customPrompts: Self.testPrompts)
    #expect(options.first == LLMActionSelection.none)
  }

  @Test
  func allOptionsEmptyPrompts() {
    let expectedCount = 1 + LLMAction.allCases.count
    let options = LLMActionSelection.allOptions(customPrompts: [])
    #expect(options.count == expectedCount)
  }

  @Test
  func displayNamePreset() {
    let name = LLMActionSelection.preset(.formal).displayName(customPrompts: Self.testPrompts)
    #expect(!name.isEmpty)
  }

  @Test
  func displayNameValidCustomPrompt() {
    let name = LLMActionSelection.customPrompt(Self.testPromptId)
      .displayName(customPrompts: Self.testPrompts)
    #expect(name == "Summarize")
  }

  @Test
  func displayNameInvalidCustomPromptFallsBack() {
    let name = LLMActionSelection.customPrompt(Self.missingPromptId)
      .displayName(customPrompts: Self.testPrompts)
    #expect(!name.isEmpty)
  }

  @Test
  func enabledActionsExcludingNone() {
    let result = LLMAction.enabledActions(excluding: [])
    #expect(result == LLMAction.allCases)
  }

  @Test
  func enabledActionsExcludingSome() {
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
  func enabledActionsExcludingAll() {
    let disabled = Set(LLMAction.allCases)
    let result = LLMAction.enabledActions(excluding: disabled)
    #expect(result.isEmpty)
  }

  @Test
  func allOptionsWithDisabledActions() {
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
  func resolvePresetDisabled() {
    let result = LLMActionSelection.preset(.formal).resolve(
      defaultAction: .rewrite,
      customPrompts: Self.testPrompts,
      disabledActions: [.formal],
    )
    #expect(result == nil)
  }

  @Test
  func resolvePresetNotDisabled() {
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
