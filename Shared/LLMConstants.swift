
import Foundation

enum ChatTemplate: String, CaseIterable, Codable, Sendable {
  case chatml
  case qwenNoThinking = "qwen-no-thinking"
  case gemma
  case llama

  var assistantPrefix: String {
    switch self {
    case .qwenNoThinking: "<think>\n\n</think>\n\n"
    case .chatml, .gemma, .llama: ""
    }
  }

  func answer(from text: String) -> String? {
    guard text.contains("<think>") else { return text }

    var result = text
    while let startRange = result.range(of: "<think>") {
      if let endRange = result.range(of: "</think>", range: startRange.upperBound ..< result.endIndex) {
        result.removeSubrange(startRange.lowerBound ..< endRange.upperBound)
      } else {
        result.removeSubrange(startRange.lowerBound ..< result.endIndex)
      }
    }

    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func applyingAssistantPrefix(to prompt: String) -> String {
    let prefix = self.assistantPrefix
    guard !prefix.isEmpty else { return prompt }
    return prompt.hasSuffix("\n") ? prompt + prefix : prompt + "\n" + prefix
  }
}

enum LLMModelVariant: String, CaseIterable, Identifiable, Codable, Sendable {
  case qwen35Small = "qwen35-0.8b-q4km"
  case gemma3One = "gemma3-1b-q5km"
  case llama32One = "llama32-1b-q5km"
  case smollm2Medium = "smollm2-1.7b-q4km"
  case qwen35Large = "qwen35-2b-q5km"
  case qwen3Small = "qwen3-0.6b-q5km"
  case qwen3Large = "qwen3-1.7b-q8"

  static var allSupportedLanguages: Set<String> {
    Self.allCases.reduce(into: Set<String>()) { $0.formUnion($1.supportedLanguages) }
  }

  static var current: [Self] {
    Self.allCases.filter { !$0.isSuperseded }
  }

  var id: String {
    rawValue
  }

  var displayName: String {
    switch self {
    case .qwen35Small: "Qwen 3.5 0.8B"
    case .gemma3One: "Gemma 3 1B"
    case .llama32One: "Llama 3.2 1B"
    case .smollm2Medium: "SmolLM2 1.7B"
    case .qwen35Large: "Qwen 3.5 2B"
    case .qwen3Small: "Qwen 3 0.6B"
    case .qwen3Large: "Qwen 3 1.7B"
    }
  }

  var descriptionKey: String {
    switch self {
    case .qwen35Small, .qwen3Small: "Smallest and fastest model. Basic quality with multilingual support."
    case .gemma3One: "Better quality than Qwen 3 0.6B. Multilingual support."
    case .llama32One: "Similar quality to Gemma 3. Stronger in English, weaker multilingual."
    case .smollm2Medium: "Higher quality than 1B models. English-focused, slower processing."
    case .qwen35Large: "Best overall quality and the widest language coverage. Slower than the 1B models."
    case .qwen3Large: "Highest quality model. Best multilingual support, but slowest."
    }
  }

  var downloadSizeMB: Int {
    switch self {
    case .qwen35Small: 562
    case .gemma3One: 851
    case .llama32One: 912
    case .smollm2Medium: 1056
    case .qwen35Large: 1540
    case .qwen3Small: 551
    case .qwen3Large: 2165
    }
  }

  var ramRequirementMB: Int {
    switch self {
    case .qwen35Small: 750
    case .gemma3One: 1000
    case .llama32One: 1050
    case .smollm2Medium: 1550
    case .qwen35Large: 1850
    case .qwen3Small: 700
    case .qwen3Large: 2500
    }
  }

  var quality: Double {
    switch self {
    case .qwen35Small: 0.60
    case .gemma3One: 0.65
    case .llama32One: 0.60
    case .smollm2Medium: 0.75
    case .qwen35Large: 0.88
    case .qwen3Small: 0.55
    case .qwen3Large: 0.85
    }
  }

  var speed: Double {
    switch self {
    case .qwen35Small: 0.92
    case .gemma3One: 0.80
    case .llama32One: 0.78
    case .smollm2Medium: 0.60
    case .qwen35Large: 0.52
    case .qwen3Small: 0.95
    case .qwen3Large: 0.45
    }
  }

  var languageTagKey: String {
    switch self {
    case .qwen35Small, .qwen35Large: "200+ languages"
    case .gemma3One: "140 languages"
    case .llama32One: "8 languages"
    case .smollm2Medium: "English"
    case .qwen3Small, .qwen3Large: "100+ languages"
    }
  }

  var supportedLanguages: Set<String> {
    switch self {
    case .qwen35Small, .qwen35Large, .qwen3Small, .qwen3Large, .gemma3One:
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

  var isSuperseded: Bool {
    self.successor != nil
  }

  var successor: Self? {
    switch self {
    case .qwen3Small: .qwen35Small
    case .qwen3Large: .qwen35Large
    case .qwen35Small, .qwen35Large, .gemma3One, .llama32One, .smollm2Medium: nil
    }
  }

  var ggufFileName: String {
    switch self {
    case .qwen35Small: "qwen3.5-0.8b-q4_k_m.gguf"
    case .gemma3One: "gemma3-1b-q5_k_m.gguf"
    case .llama32One: "llama-3.2-1b-q5_k_m.gguf"
    case .smollm2Medium: "smollm2-1.7b-q4_k_m.gguf"
    case .qwen35Large: "qwen3.5-2b-q5_k_m.gguf"
    case .qwen3Small: "qwen3-0.6b-q5_k_m.gguf"
    case .qwen3Large: "qwen3-1.7b-q8_0.gguf"
    }
  }

  var minRAMBytes: UInt64 {
    (self.ramRequirementMB + Self.systemOverheadMB).megabytesInBytes
  }

  var chatTemplate: ChatTemplate {
    switch self {
    case .qwen35Small, .qwen35Large, .qwen3Small, .qwen3Large: .qwenNoThinking
    case .gemma3One: .gemma
    case .llama32One: .llama
    case .smollm2Medium: .chatml
    }
  }

  var contextSize: Int {
    switch self {
    case .gemma3One, .llama32One, .qwen3Small, .qwen35Small:
      1024
    case .smollm2Medium, .qwen3Large, .qwen35Large:
      2048
    }
  }

  var isSupportedOnCurrentDevice: Bool {
    ProcessInfo.processInfo.physicalMemory >= self.minRAMBytes
  }

  func formattedDownloadSize(locale: Locale = .current) -> String {
    self.downloadSizeMB.formattedAsBytes(locale: locale)
  }

  func formattedRAM(locale: Locale = .current) -> String {
    self.ramRequirementMB.formattedAsBytes(locale: locale)
  }

  private static let systemOverheadMB = 2000

}

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

  static func enabledActions(excluding disabled: Set<Self>) -> [Self] {
    allCases.filter { !disabled.contains($0) }
  }
}

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

enum LLMActionSelection: Codable, Hashable, Sendable {
  case none
  case preset(LLMAction)
  case customPrompt(UUID)

  var isSet: Bool {
    switch self {
    case .none: false
    case .preset, .customPrompt: true
    }
  }

  static func allOptions(
    customPrompts: [LLMCustomPrompt],
    disabledActions: Set<LLMAction> = [],
  ) -> [Self] {
    var options: [Self] = [.none]
    options += LLMAction.enabledActions(excluding: disabledActions).map { .preset($0) }
    options += customPrompts.map { .customPrompt($0.id) }
    return options
  }

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
