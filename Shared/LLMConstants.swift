// LLMConstants -- Model definitions, actions, and custom prompts for on-device LLM text processing

import Foundation

// MARK: - ChatTemplate

enum ChatTemplate: String, Codable, Sendable {
  case chatml
  case gemma
  case llama
}

// MARK: - LLMModelVariant

enum LLMModelVariant: String, CaseIterable, Identifiable, Codable, Sendable {
  case qwen3Small = "qwen3-0.6b-q5km"
  case gemma3One = "gemma3-1b-q5km"
  case llama32One = "llama32-1b-q5km"
  case smollm2Medium = "smollm2-1.7b-q4km"
  case qwen3Large = "qwen3-1.7b-q8"

  // MARK: Internal

  static var allSupportedLanguages: Set<String> {
    Self.allCases.reduce(into: Set<String>()) { $0.formUnion($1.supportedLanguages) }
  }

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .qwen3Small: "Qwen 3 0.6B"
    case .gemma3One: "Gemma 3 1B"
    case .llama32One: "Llama 3.2 1B"
    case .smollm2Medium: "SmolLM2 1.7B"
    case .qwen3Large: "Qwen 3 1.7B"
    }
  }

  var descriptionKey: String {
    switch self {
    case .qwen3Small: "Smallest and fastest model. Basic quality with multilingual support."
    case .gemma3One: "Better quality than Qwen 3 0.6B. Multilingual support."
    case .llama32One: "Similar quality to Gemma 3. Stronger in English, weaker multilingual."
    case .smollm2Medium: "Higher quality than 1B models. English-focused, slower processing."
    case .qwen3Large: "Highest quality model. Best multilingual support, but slowest."
    }
  }

  var downloadSizeMB: Int {
    switch self {
    case .qwen3Small: 551
    case .gemma3One: 851
    case .llama32One: 912
    case .smollm2Medium: 1056
    case .qwen3Large: 2165
    }
  }

  var ramRequirementMB: Int {
    switch self {
    case .qwen3Small: 700
    case .gemma3One: 1000
    case .llama32One: 1050
    case .smollm2Medium: 1550
    case .qwen3Large: 2500
    }
  }

  var quality: Double {
    switch self {
    case .qwen3Small: 0.55
    case .gemma3One: 0.65
    case .llama32One: 0.60
    case .smollm2Medium: 0.75
    case .qwen3Large: 0.85
    }
  }

  var speed: Double {
    switch self {
    case .qwen3Small: 0.95
    case .gemma3One: 0.80
    case .llama32One: 0.78
    case .smollm2Medium: 0.60
    case .qwen3Large: 0.45
    }
  }

  var languageTagKey: String {
    switch self {
    case .qwen3Small: "100+ languages"
    case .gemma3One: "140 languages"
    case .llama32One: "8 languages"
    case .smollm2Medium: "English"
    case .qwen3Large: "100+ languages"
    }
  }

  var supportedLanguages: Set<String> {
    switch self {
    case .qwen3Small, .qwen3Large, .gemma3One:
      SpeechLanguages.whisper
    case .llama32One:
      ["en", "de", "fr", "it", "pt", "hi", "es", "th"]
    case .smollm2Medium:
      SpeechLanguages.englishOnly
    }
  }

  var isRecommended: Bool {
    self == .gemma3One
  }

  var ggufFileName: String {
    switch self {
    case .qwen3Small: "qwen3-0.6b-q5_k_m.gguf"
    case .gemma3One: "gemma3-1b-q5_k_m.gguf"
    case .llama32One: "llama-3.2-1b-q5_k_m.gguf"
    case .smollm2Medium: "smollm2-1.7b-q4_k_m.gguf"
    case .qwen3Large: "qwen3-1.7b-q8_0.gguf"
    }
  }

  /// Minimum device RAM in bytes required to safely run this model.
  /// Computed as model RAM requirement + system overhead (iOS + app baseline + safety margin).
  var minRAMBytes: UInt64 {
    UInt64(self.ramRequirementMB + Self.systemOverheadMB) * 1_000_000
  }

  var chatTemplate: ChatTemplate {
    switch self {
    case .qwen3Small, .qwen3Large: .chatml
    case .gemma3One: .gemma
    case .llama32One: .llama
    case .smollm2Medium: .chatml
    }
  }

  /// Context window size in tokens for this model.
  var contextSize: Int {
    switch self {
    case .qwen3Small, .gemma3One, .llama32One:
      1024
    case .smollm2Medium, .qwen3Large:
      2048
    }
  }

  /// Whether the current device has enough RAM for this model.
  var isSupportedOnCurrentDevice: Bool {
    ProcessInfo.processInfo.physicalMemory >= self.minRAMBytes
  }

  func formattedDownloadSize(locale: Locale = .current) -> String {
    self.downloadSizeMB.formattedAsBytes(locale: locale)
  }

  func formattedRAM(locale: Locale = .current) -> String {
    self.ramRequirementMB.formattedAsBytes(locale: locale)
  }

  // MARK: Private

  /// Overhead in MB for iOS system (~1.5 GB) + app baseline (~0.3 GB) + safety margin (~0.2 GB).
  private static let systemOverheadMB = 2000

}

// MARK: - LLMAction

enum LLMAction: String, CaseIterable, Codable, Sendable {
  case removeRedundancy
  case rewrite
  case formal
  case casual
  case fixGrammar
  case simplify
  case continueWriting
  case shorten
  case bulletPoints
  case summarize
  case expand
  case addPunctuation

  // MARK: Internal

  var displayNameKey: String {
    switch self {
    case .removeRedundancy: "Remove redundancy"
    case .rewrite: "Rewrite"
    case .formal: "Formal"
    case .casual: "Casual"
    case .fixGrammar: "Fix grammar"
    case .simplify: "Simplify"
    case .continueWriting: "Continue writing"
    case .shorten: "Shorten"
    case .bulletPoints: "Bullet points"
    case .summarize: "Summarize"
    case .expand: "Expand"
    case .addPunctuation: "Add punctuation"
    }
  }

  /// Returns all cases not in the disabled set.
  static func enabledActions(excluding disabled: Set<Self>) -> [Self] {
    allCases.filter { !disabled.contains($0) }
  }
}

// MARK: - LLMCustomPrompt

struct LLMCustomPrompt: Codable, Identifiable, Sendable, Equatable {
  init(id: UUID = UUID(), name: String, prompt: String) {
    self.id = id
    self.name = name
    self.prompt = prompt
  }

  let id: UUID
  var name: String
  var prompt: String

}

// MARK: - LLMActionSelection

enum LLMActionSelection: Codable, Hashable, Sendable {
  case none
  case preset(LLMAction)
  case customPrompt(UUID)

  // MARK: Internal

  var isSet: Bool {
    switch self {
    case .none: false
    case .preset, .customPrompt: true
    }
  }

  /// Combined list: `.none` + enabled presets + all custom prompts (by UUID).
  static func allOptions(
    customPrompts: [LLMCustomPrompt],
    disabledActions: Set<LLMAction> = [],
  ) -> [Self] {
    var options: [Self] = [.none]
    options += LLMAction.enabledActions(excluding: disabledActions).map { .preset($0) }
    options += customPrompts.map { .customPrompt($0.id) }
    return options
  }

  /// Resolves the selection into the action/customPromptId tuple that `requestLLMProcessing` expects.
  /// Returns nil for `.none`, disabled presets, or if a custom prompt ID no longer exists.
  func resolve(
    defaultAction: LLMAction,
    customPrompts: [LLMCustomPrompt],
    disabledActions: Set<LLMAction> = [],
  ) -> (action: LLMAction, customPromptId: UUID?)? {
    switch self {
    case .none:
      return nil

    case .preset(let action):
      guard !disabledActions.contains(action) else { return nil }
      return (action: action, customPromptId: nil)

    case .customPrompt(let id):
      guard customPrompts.contains(where: { $0.id == id }) else { return nil }
      return (action: defaultAction, customPromptId: id)
    }
  }

  /// Human-readable name for picker display.
  func displayName(customPrompts: [LLMCustomPrompt]) -> String {
    switch self {
    case .none:
      String(localized: "Off")
    case .preset(let action):
      String(localized: String.LocalizationValue(action.displayNameKey))
    case .customPrompt(let id):
      customPrompts.first { $0.id == id }?.name
        ?? String(localized: "Off")
    }
  }
}
