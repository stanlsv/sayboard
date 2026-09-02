

import Foundation
import llama

enum LLMLoadState: Sendable, Equatable {
  case unloaded
  case loading
  case loaded
  case error(String)
}

private struct SendablePointer: @unchecked Sendable {
  let pointer: OpaquePointer
}

private enum LLMBackend {

  static func ensureInitialized() {
    _ = self._initialized
  }

  private static let _initialized: Void = {
    llama_log_set({ level, text, _ in
      guard level.rawValue >= GGML_LOG_LEVEL_WARN.rawValue, let text else { return }
      let message = String(cString: text).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !message.isEmpty else { return }
      DiagnosticLog.write("llama.cpp: \(message)")
    }, nil)
    llama_backend_init()
  }()

}

@MainActor
final class LLMInferenceService: ObservableObject {

  @Published private(set) var loadState = LLMLoadState.unloaded

  func loadModel(variant: LLMModelVariant, path: String) async {
    guard self.loadState != .loading else { return }
    self.loadState = .loading
    self.currentVariant = variant

    let availableMemory = os_proc_available_memory()
    let requiredMemory = UInt64(Double(variant.ramRequirementMB.megabytesInBytes) * Self.memoryCheckSafetyMultiplier)
    if availableMemory < requiredMemory {
      let availableMB = availableMemory / 1_000_000
      let requiredMB = requiredMemory / 1_000_000
      let _ = variant.rawValue
      DiagnosticLog.write("llm: load refused, \(availableMB)MB free < \(requiredMB)MB needed")
      self.loadState = .error("Not enough free memory to load this model. Close other apps and try again.")
      return
    }
    let footprintBefore = ProcessFootprint.residentMB()
    DiagnosticLog.write(
      "llm: loading \(variant.rawValue), \(os_proc_available_memory() / 1_000_000)MB free, "
        + "footprint \(footprintBefore)MB"
    )

    let contextSize = variant.contextSize
    let threadCount = Self.inferenceThreadCount
    let result: (model: SendablePointer, context: SendablePointer)? =
      await Task.detached(priority: .userInitiated) {
        LLMBackend.ensureInitialized()

        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = 0

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
      let footprintAfter = ProcessFootprint.residentMB()
      DiagnosticLog.write(
        "llm: loaded ok, \(os_proc_available_memory() / 1_000_000)MB free after, "
          + "footprint \(footprintAfter)MB (+\(footprintAfter - footprintBefore)MB), "
          + "declared \(variant.ramRequirementMB)MB"
      )
      DiagnosticLog.write("llm: backends -- \(Self.systemInfo())")
    } else {
      self.loadState = .error("Failed to load LLM model")
      DiagnosticLog.write("llm: llama.cpp refused \(variant.rawValue) — unsupported arch or bad file?")
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

  func process(systemPrompt: String, userText: String, assistantPrefill: String = "") async -> String? {
    let prompt = Prompt(system: systemPrompt, user: userText, assistantPrefill: assistantPrefill)
    guard
      let model = self.model,
      let context = self.context,
      let variant = self.currentVariant
    else {
      return nil
    }

    self.isProcessing = true
    defer { self.isProcessing = false }

    let sendableModel = SendablePointer(pointer: model)
    let sendableCtx = SendablePointer(pointer: context)

    return await Task.detached(priority: .userInitiated) {
      Self.runInference(
        model: sendableModel.pointer,
        context: sendableCtx.pointer,
        variant: variant,
        prompt: prompt,
      )
    }.value
  }

  private struct Prompt: Sendable {
    let system: String
    let user: String
    let assistantPrefill: String
  }

  private nonisolated static let contextReserveTokens = 16

  private nonisolated static let pieceBufferSize = 64

  private nonisolated static let generationDeadlineSeconds: TimeInterval = 15
  private nonisolated static let memoryCheckSafetyMultiplier = 1.2
  private nonisolated static let temperature: Float = 0.3
  private nonisolated static let topP: Float = 0.9
  private static let inferenceThreadCount = max(2, min(ProcessInfo.processInfo.activeProcessorCount - 1, 4))

  private var model: OpaquePointer?
  private var context: OpaquePointer?
  private var currentVariant: LLMModelVariant?
  private var isProcessing = false

  private nonisolated static func systemInfo() -> String {
    guard let raw = llama_print_system_info() else { return "unavailable" }
    return String(cString: raw).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private nonisolated static func runInference(
    model: OpaquePointer,
    context: OpaquePointer,
    variant: LLMModelVariant,
    prompt: Prompt,
  ) -> String? {
    let template = variant.chatTemplate
    let promptString = self.buildFormattedPrompt(
      model: model,
      system: prompt.system,
      user: prompt.user,
      chatTemplate: template,
    ) + prompt.assistantPrefill

    let vocab = llama_model_get_vocab(model)
    let tokens = self.tokenize(vocab: vocab, prompt: promptString)
    guard !tokens.isEmpty else { return nil }

    llama_memory_clear(llama_get_memory(context), true)

    var batch = llama_batch_init(Int32(tokens.count), 0, 1)
    defer { llama_batch_free(batch) }

    guard self.decodePrompt(context: context, batch: &batch, tokens: tokens) else { return nil }

    let maxTokens = variant.contextSize - tokens.count - self.contextReserveTokens
    guard maxTokens > 0 else {
      DiagnosticLog.write("llm: prompt \(tokens.count) tok exceeds ctx \(variant.contextSize)")
      return nil
    }
    DiagnosticLog.write("llm: prompt=\(tokens.count) tok, budget=\(maxTokens) tok, ctx=\(variant.contextSize)")

    guard
      let generated = self.generateTokens(
        context: context,
        vocab: vocab,
        batch: &batch,
        startPos: Int32(tokens.count),
        maxTokens: maxTokens,
      )
    else {
      DiagnosticLog.write("llm: generation failed")
      return nil
    }
    DiagnosticLog.write(
      "llm: raw=\(generated.text.count) chars, eos=\(generated.stoppedAtEOS), "
        + "closingTag=\(generated.text.contains("</think>")), "
        + "peak footprint \(ProcessFootprint.residentMB())MB"
    )

    guard let answer = template.answer(from: generated.text), !answer.isEmpty else {
      DiagnosticLog.write("llm: FAILED, no answer extracted from reply")
      return nil
    }
    DiagnosticLog.write("llm: answer=\(answer.count) chars")
    return prompt.assistantPrefill + answer
  }

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
  ) -> (text: String, stoppedAtEOS: Bool)? {
    guard let sampler = self.makeSampler() else {
      return nil
    }
    defer { llama_sampler_free(sampler) }

    var outputPieces = [String]()
    var currentPos = startPos
    var stoppedAtEOS = false
    var hitDeadline = false
    let eosToken = llama_vocab_eos(vocab)
    let eotToken = llama_vocab_eot(vocab)
    let startedAt = Date()

    for index in 0 ..< maxTokens {
      guard !Task.isCancelled else {
        DiagnosticLog.write("llm: cancelled after \(index) tok in \(Self.elapsed(since: startedAt))s")
        break
      }
      if index > 0, index.isMultiple(of: 32) {
        DiagnosticLog.write("llm: \(index) tok in \(Self.elapsed(since: startedAt))s")
      }
      if Date().timeIntervalSince(startedAt) > Self.generationDeadlineSeconds {
        DiagnosticLog.write("llm: DEADLINE after \(index) tok in \(Self.elapsed(since: startedAt))s")
        hitDeadline = true
        break
      }

      let newToken = llama_sampler_sample(sampler, context, -1)
      if newToken == eosToken || newToken == eotToken || llama_vocab_is_eog(vocab, newToken) {
        stoppedAtEOS = true
        break
      }

      if let piece = self.piece(vocab: vocab, token: newToken) {
        outputPieces.append(piece)
      }

      batch.n_tokens = 0
      self.batchAdd(&batch, token: newToken, pos: currentPos, seqIds: [0], logits: true)
      currentPos += 1

      guard llama_decode(context, batch) == 0 else {
        break
      }
    }

    guard !hitDeadline else { return nil }

    let raw = outputPieces.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    DiagnosticLog.write(
      "llm: generation done, \(outputPieces.count) tok in \(Self.elapsed(since: startedAt))s, eos=\(stoppedAtEOS)"
    )
    return (text: raw, stoppedAtEOS: stoppedAtEOS)
  }

  private nonisolated static func piece(vocab: OpaquePointer?, token: llama_token) -> String? {
    var buffer = [CChar](repeating: 0, count: self.pieceBufferSize)
    let written = llama_token_to_piece(vocab, token, &buffer, Int32(self.pieceBufferSize), 0, true)
    guard written > 0 else { return nil }
    let bytes = buffer.prefix(Int(written)).map { UInt8(bitPattern: $0) }
    return String(bytes: bytes, encoding: .utf8)
  }

  private nonisolated static func makeSampler() -> UnsafeMutablePointer<llama_sampler>? {
    guard let sampler = llama_sampler_chain_init(llama_sampler_chain_default_params()) else {
      return nil
    }
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(self.temperature))
    llama_sampler_chain_add(sampler, llama_sampler_init_top_p(self.topP, 1))
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0 ... UInt32.max)))
    return sampler
  }

  private nonisolated static func elapsed(since start: Date) -> String {
    String(format: "%.1f", Date().timeIntervalSince(start))
  }

  private nonisolated static func buildFormattedPrompt(
    model: OpaquePointer,
    system: String,
    user: String,
    chatTemplate: ChatTemplate,
  ) -> String {
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

    let requiredSize = llama_chat_apply_template(
      llama_model_chat_template(model, nil),
      &messages,
      messages.count,
      true,
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
          return chatTemplate.applyingAssistantPrefix(to: result)
        }
      }
    }

    let manual = LLMPromptTemplates.buildPrompt(system: system, user: user, template: chatTemplate)
    return chatTemplate.applyingAssistantPrefix(to: manual)
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
