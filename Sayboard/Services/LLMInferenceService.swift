// LLMInferenceService -- On-device LLM inference via llama.cpp C API

import Foundation
import llama

// MARK: - LLMLoadState

enum LLMLoadState: Sendable, Equatable {
  case unloaded
  case loading
  case loaded
  case error(String)
}

// MARK: - SendablePointer

// llama.cpp C pointers are thread-safe; wraps OpaquePointer for cross-actor transfer
// swiftlint:disable:next no_unchecked_sendable
private struct SendablePointer: @unchecked Sendable {
  let pointer: OpaquePointer
}

// MARK: - LLMBackend

private enum LLMBackend {
  static func ensureInitialized() {
    _ = self._initialized
  }

  /// One-time llama.cpp backend initialization. Swift guarantees `static let` is
  /// initialized exactly once via dispatch_once, making this thread-safe.
  private static let _initialized: Void = {
    llama_backend_init()
  }()

}

// MARK: - LLMInferenceService

@MainActor
final class LLMInferenceService: ObservableObject {

  // MARK: Internal

  @Published private(set) var loadState = LLMLoadState.unloaded

  func loadModel(variant: LLMModelVariant, path: String) async {
    guard self.loadState != .loading else { return }
    self.loadState = .loading
    self.currentVariant = variant

    let availableMemory = os_proc_available_memory()
    let requiredMemory = UInt64(Double(variant.ramRequirementMB) * Self.memoryCheckSafetyMultiplier * 1_000_000)
    if availableMemory < requiredMemory {
      let model = variant.rawValue
      self.loadState = .error("Not enough free memory to load this model. Close other apps and try again.")
      return
    }

    let contextSize = variant.contextSize
    let threadCount = Self.inferenceThreadCount
    let result: (model: SendablePointer, context: SendablePointer)? =
      await Task.detached(priority: .userInitiated) {
        LLMBackend.ensureInitialized()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 0 // CPU-only: Metal GPU blocked when app is backgrounded

        guard let model = llama_model_load_from_file(path, modelParams) else {
          return nil
        }

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(contextSize)
        ctxParams.n_batch = 512
        ctxParams.n_threads = Int32(threadCount)
        ctxParams.n_threads_batch = Int32(threadCount)
        ctxParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_DISABLED
        ctxParams.offload_kqv = false
        ctxParams.op_offload = false

        guard let ctx = llama_init_from_model(model, ctxParams) else {
          llama_model_free(model)
          return nil
        }

        return (SendablePointer(pointer: model), SendablePointer(pointer: ctx))
      }.value

    if let result {
      self.model = result.model.pointer
      self.context = result.context.pointer
      self.loadState = .loaded
    } else {
      self.loadState = .error("Failed to load LLM model")
    }
  }

  func unloadModel() {
    guard self.model != nil else { return }
    guard !self.isProcessing else {
      return
    }
    if let ctx = self.context {
      llama_free(ctx)
    }
    if let mdl = self.model {
      llama_model_free(mdl)
    }
    self.context = nil
    self.model = nil
    self.currentVariant = nil
    self.loadState = .unloaded
  }

  /// Runs inference with the given prompts. Returns the generated text, or nil on failure.
  func process(systemPrompt: String, userText: String) async -> String? {
    guard
      let model = self.model,
      let context = self.context,
      let variant = self.currentVariant
    else {
      return nil
    }

    self.isProcessing = true
    defer { self.isProcessing = false }

    let chatTemplate = variant.chatTemplate
    let maxTokens = Self.maxOutputTokens
    let sendableModel = SendablePointer(pointer: model)
    let sendableCtx = SendablePointer(pointer: context)

    return await Task.detached(priority: .userInitiated) {
      let mdl = sendableModel.pointer
      let ctx = sendableCtx.pointer

      let promptString = Self.buildFormattedPrompt(
        model: mdl,
        system: systemPrompt,
        user: userText,
        chatTemplate: chatTemplate,
      )

      let vocab = llama_model_get_vocab(mdl)
      let tokens = Self.tokenize(vocab: vocab, prompt: promptString)
      guard !tokens.isEmpty else { return nil as String? }

      llama_memory_clear(llama_get_memory(ctx), true)

      var batch = llama_batch_init(Int32(tokens.count), 0, 1)
      defer { llama_batch_free(batch) }

      guard Self.decodePrompt(context: ctx, batch: &batch, tokens: tokens) else {
        return nil as String?
      }

      return Self.generateTokens(
        context: ctx,
        vocab: vocab,
        batch: &batch,
        startPos: Int32(tokens.count),
        maxTokens: maxTokens,
      )
    }.value
  }

  // MARK: Private

  private static let maxOutputTokens = 512
  private nonisolated static let memoryCheckSafetyMultiplier = 1.2
  private nonisolated static let temperature: Float = 0.3
  private nonisolated static let topP: Float = 0.9
  private static let inferenceThreadCount = max(2, min(ProcessInfo.processInfo.activeProcessorCount - 1, 4))

  private var model: OpaquePointer?
  private var context: OpaquePointer?
  private var currentVariant: LLMModelVariant?
  private var isProcessing = false

  /// Returns tokenized prompt, or empty array on failure.
  private nonisolated static func tokenize(
    vocab: OpaquePointer?,
    prompt: String,
  ) -> [llama_token] {
    let promptCStr = prompt.cString(using: .utf8) ?? []
    let maxTokens = Int32(prompt.utf8.count + 128)
    var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
    let count = llama_tokenize(
      vocab,
      promptCStr,
      Int32(promptCStr.count - 1),
      &tokens,
      maxTokens,
      true,
      true,
    )
    guard count > 0 else {
      return []
    }
    return Array(tokens.prefix(Int(count)))
  }

  private nonisolated static func decodePrompt(
    context: OpaquePointer,
    batch: inout llama_batch,
    tokens: [llama_token],
  ) -> Bool {
    for (i, token) in tokens.enumerated() {
      self.batchAdd(&batch, token: token, pos: Int32(i), seqIds: [0], logits: i == tokens.count - 1)
    }
    guard llama_decode(context, batch) == 0 else {
      return false
    }
    return true
  }

  private nonisolated static func generateTokens(
    context: OpaquePointer,
    vocab: OpaquePointer?,
    batch: inout llama_batch,
    startPos: Int32,
    maxTokens: Int,
  ) -> String? {
    let samplerParams = llama_sampler_chain_default_params()
    guard let sampler = llama_sampler_chain_init(samplerParams) else {
      return nil
    }
    defer { llama_sampler_free(sampler) }

    llama_sampler_chain_add(sampler, llama_sampler_init_temp(self.temperature))
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(self.topP, 1))
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0 ... UInt32.max)))

    var outputPieces = [String]()
    var currentPos = startPos
    let eosToken = llama_vocab_eos(vocab)
    let eotToken = llama_vocab_eot(vocab)

    for _ in 0 ..< maxTokens {
      guard !Task.isCancelled else { break }

      let newToken = llama_sampler_sample(sampler, context, -1)
      if newToken == eosToken || newToken == eotToken || llama_vocab_is_eog(vocab, newToken) { break }

      var buf = [CChar](repeating: 0, count: 64)
      let written = llama_token_to_piece(vocab, newToken, &buf, 64, 0, true)
      if written > 0 {
        let bytes = buf.prefix(Int(written)).map { UInt8(bitPattern: $0) }
        if let piece = String(bytes: bytes, encoding: .utf8) {
          outputPieces.append(piece)
        }
      }

      batch.n_tokens = 0
      self.batchAdd(&batch, token: newToken, pos: currentPos, seqIds: [0], logits: true)
      currentPos += 1

      guard llama_decode(context, batch) == 0 else {
        break
      }
    }

    var output = outputPieces.joined().trimmingCharacters(in: .whitespacesAndNewlines)

    // Strip Qwen3 <think>...</think> reasoning blocks
    output = Self.stripThinkingBlocks(output)

    return output.isEmpty ? nil : output
  }

  /// Builds formatted prompt string. Tries llama_chat_apply_template() first, falls back to manual formatting.
  private nonisolated static func buildFormattedPrompt(
    model: OpaquePointer,
    system: String,
    user: String,
    chatTemplate: ChatTemplate,
  ) -> String {
    // Try llama_chat_apply_template from GGUF metadata
    var messages = [
      llama_chat_message(role: strdup("system"), content: strdup(system)),
      llama_chat_message(role: strdup("user"), content: strdup(user)),
    ]
    defer {
      for msg in messages {
        free(UnsafeMutablePointer(mutating: msg.role))
        free(UnsafeMutablePointer(mutating: msg.content))
      }
    }

    // First call to get required buffer size
    let requiredSize = llama_chat_apply_template(
      llama_model_chat_template(model, nil),
      &messages,
      messages.count,
      true, // add_assistant
      nil,
      0,
    )

    if requiredSize > 0 {
      var buffer = [CChar](repeating: 0, count: Int(requiredSize) + 1)
      let written = llama_chat_apply_template(
        llama_model_chat_template(model, nil),
        &messages,
        messages.count,
        true,
        &buffer,
        Int32(buffer.count),
      )
      if written > 0 {
        let bytes = buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }
        if let result = String(bytes: bytes, encoding: .utf8) {
          return result
        }
      }
    }

    // Fallback to manual template
    return LLMPromptTemplates.buildPrompt(system: system, user: user, template: chatTemplate)
  }

  /// Strips `<think>...</think>` blocks that Qwen3 emits in thinking mode.
  private nonisolated static func stripThinkingBlocks(_ text: String) -> String {
    guard text.contains("<think>") else { return text }

    var result = text
    while let startRange = result.range(of: "<think>") {
      if let endRange = result.range(of: "</think>", range: startRange.upperBound ..< result.endIndex) {
        result.removeSubrange(startRange.lowerBound ..< endRange.upperBound)
      } else {
        // Unclosed <think> — remove everything from <think> to end
        result.removeSubrange(startRange.lowerBound ..< result.endIndex)
      }
    }

    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private nonisolated static func batchAdd(
    _ batch: inout llama_batch,
    token: llama_token,
    pos: Int32,
    seqIds: [Int32],
    logits: Bool,
  ) {
    let i = Int(batch.n_tokens)
    batch.token[i] = token
    batch.pos[i] = pos
    batch.n_seq_id[i] = Int32(seqIds.count)
    for (j, seqId) in seqIds.enumerated() {
      batch.seq_id[i]?[j] = seqId
    }
    batch.logits[i] = logits ? 1 : 0
    batch.n_tokens += 1
  }
}
