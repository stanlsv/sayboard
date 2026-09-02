import Foundation
import Testing

@testable import Sayboard

@Suite("ChatTemplate prompt shaping")
struct ChatTemplateTests {

  @Test
  func `qwen prompt gains a closed thinking block`() {
    let result = ChatTemplate.qwenNoThinking.applyingAssistantPrefix(to: Self.llamaCppChatMLHeader)
    #expect(result == Self.llamaCppChatMLHeader + "<think>\n\n</think>\n\n")
  }

  @Test
  func `the block is closed, never left open`() {
    #expect(ChatTemplate.qwenNoThinking.assistantPrefix.contains("</think>"))
  }

  @Test
  func `prompt without trailing newline gets one before the block`() {
    let result = ChatTemplate.qwenNoThinking.applyingAssistantPrefix(to: Self.headerMissingNewline)
    #expect(result == Self.headerMissingNewline + "\n<think>\n\n</think>\n\n")
  }

  @Test
  func `prefix never grows a doubled newline`() {
    let result = ChatTemplate.qwenNoThinking.applyingAssistantPrefix(to: Self.llamaCppChatMLHeader)
    #expect(!result.contains("assistant\n\n<think>"))
  }

  @Test
  func `plain chatml is left untouched`() {
    let result = ChatTemplate.chatml.applyingAssistantPrefix(to: Self.llamaCppChatMLHeader)
    #expect(result == Self.llamaCppChatMLHeader)
  }

  @Test
  func `gemma is left untouched`() {
    let prompt = "<start_of_turn>user\nhi<end_of_turn>\n<start_of_turn>model\n"
    #expect(ChatTemplate.gemma.applyingAssistantPrefix(to: prompt) == prompt)
  }

  @Test
  func `llama is left untouched`() {
    let prompt = "<|start_header_id|>assistant<|end_header_id|>\n\n"
    #expect(ChatTemplate.llama.applyingAssistantPrefix(to: prompt) == prompt)
  }

  @Test
  func `only the qwen template carries a prefix`() {
    let prefixed = ChatTemplate.allCases.filter { !$0.assistantPrefix.isEmpty }
    #expect(prefixed == [.qwenNoThinking])
  }

  @Test
  func `every qwen variant suppresses thinking`() {
    for variant in [LLMModelVariant.qwen35Small, .qwen35Large, .qwen3Small, .qwen3Large] {
      #expect(variant.chatTemplate == .qwenNoThinking, "\(variant.rawValue) would reason")
    }
  }

  @Test
  func `smollm2 stays on plain chatml`() {
    #expect(LLMModelVariant.smollm2Medium.chatTemplate == .chatml)
  }

  @Test
  func `a self-emitted reasoning block is stripped`() {
    let reply = "<think>pondering</think>Готово."
    #expect(ChatTemplate.qwenNoThinking.answer(from: reply) == "Готово.")
  }

  @Test
  func `an unterminated block takes everything after it`() {
    let reply = "Готово.<think>pondering forever"
    #expect(ChatTemplate.qwenNoThinking.answer(from: reply) == "Готово.")
  }

  @Test
  func `reasoning never survives into the answer`() {
    let reply = "<think>secret chain of thought</think>Ответ."
    let answer = ChatTemplate.qwenNoThinking.answer(from: reply) ?? ""
    #expect(!answer.contains("secret"))
    #expect(!answer.contains("<think>"))
  }

  @Test
  func `plain templates pass text through untouched`() {
    let reply = "Готово."
    #expect(ChatTemplate.chatml.answer(from: reply) == reply)
    #expect(ChatTemplate.gemma.answer(from: reply) == reply)
  }

  private static let llamaCppChatMLHeader = "<|im_start|>user\nhi<|im_end|>\n<|im_start|>assistant\n"
  private static let headerMissingNewline = "<|im_start|>user\nhi<|im_end|>\n<|im_start|>assistant"
}

@Suite("buildPrompt matches llama_chat_apply_template")
struct BuildPromptTests {

  @Test
  func `chatml closes the assistant header with a newline`() {
    let prompt = LLMPromptTemplates.buildPrompt(system: "S", user: "U", template: .chatml)
    #expect(prompt == "<|im_start|>system\nS<|im_end|>\n<|im_start|>user\nU<|im_end|>\n<|im_start|>assistant\n")
  }

  @Test
  func `qwen shares the chatml shape`() {
    let chatml = LLMPromptTemplates.buildPrompt(system: "S", user: "U", template: .chatml)
    let qwen = LLMPromptTemplates.buildPrompt(system: "S", user: "U", template: .qwenNoThinking)
    #expect(chatml == qwen)
  }

  @Test
  func `gemma folds the system turn into the user turn and closes with a newline`() {
    let prompt = LLMPromptTemplates.buildPrompt(system: "S", user: "U", template: .gemma)
    #expect(prompt == "<start_of_turn>user\nS\n\nU<end_of_turn>\n<start_of_turn>model\n")
  }

  @Test
  func `llama closes the assistant header with a blank line`() {
    let prompt = LLMPromptTemplates.buildPrompt(system: "S", user: "U", template: .llama)
    #expect(prompt.hasSuffix("<|start_header_id|>assistant<|end_header_id|>\n\n"))
  }

  @Test
  func `no template writes a bos token`() {
    for template in Sayboard.ChatTemplate.allCases {
      let prompt = LLMPromptTemplates.buildPrompt(system: "S", user: "U", template: template)
      #expect(!prompt.contains("<|begin_of_text|>"), "\(template.rawValue) emits a second BOS")
    }
  }

  @Test
  func `every template ends ready for the model to speak`() {
    for template in Sayboard.ChatTemplate.allCases {
      let prompt = LLMPromptTemplates.buildPrompt(system: "S", user: "U", template: template)
      #expect(prompt.hasSuffix("\n"), "\(template.rawValue) leaves the header unterminated")
    }
  }

  @Test
  func `the thinking block follows the qwen header with a single newline`() {
    let prompt = LLMPromptTemplates.buildPrompt(system: "S", user: "U", template: .qwenNoThinking)
    let withPrefix = ChatTemplate.qwenNoThinking.applyingAssistantPrefix(to: prompt)
    #expect(withPrefix.hasSuffix("<|im_start|>assistant\n<think>\n\n</think>\n\n"))
  }
}
