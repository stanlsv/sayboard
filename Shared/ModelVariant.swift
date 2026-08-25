import Foundation

enum STTEngine: String, Codable, Sendable {
  case whisperKit
  case parakeet
  case moonshine

  var sectionTitle: String {
    switch self {
    case .whisperKit: "Whisper"
    case .parakeet: "Parakeet"
    case .moonshine: "Moonshine"
    }
  }
}

enum ModelVariant: String, CaseIterable, Identifiable, Codable, Sendable {
  case whisperTiny = "openai_whisper-tiny"
  case whisperBase = "openai_whisper-base"
  case whisperSmall = "openai_whisper-small"
  case parakeetV2 = "parakeet-tdt-0.6b-v2"
  case parakeetV3 = "parakeet-tdt-0.6b-v3"
  case moonshineTiny = "moonshine-tiny-en"
  case moonshineBase = "moonshine-base-en"
  case moonshineTinyStreaming = "moonshine-tiny-streaming-en"
  case moonshineSmallStreaming = "moonshine-small-streaming-en"
  case moonshineMediumStreaming = "moonshine-medium-streaming-en"

  var id: String {
    rawValue
  }

  var engine: STTEngine {
    switch self {
    case .whisperTiny, .whisperBase, .whisperSmall:
      .whisperKit
    case .parakeetV2, .parakeetV3:
      .parakeet
    case .moonshineTiny, .moonshineBase, .moonshineTinyStreaming, .moonshineSmallStreaming, .moonshineMediumStreaming:
      .moonshine
    }
  }

  var displayName: String {
    switch self {
    case .whisperTiny: "Whisper Tiny"
    case .whisperBase: "Whisper Base"
    case .whisperSmall: "Whisper Small"
    case .parakeetV2: "Parakeet v2"
    case .parakeetV3: "Parakeet v3"
    case .moonshineTiny: "Moonshine Tiny"
    case .moonshineBase: "Moonshine Base"
    case .moonshineTinyStreaming: "Moonshine Tiny Streaming"
    case .moonshineSmallStreaming: "Moonshine Small Streaming"
    case .moonshineMediumStreaming: "Moonshine Medium Streaming"
    }
  }

  var descriptionKey: String {
    switch self {
    case .whisperTiny: "Lightest multilingual model. Basic accuracy, but supports 100 languages."
    case .whisperBase: "Better accuracy than Whisper Tiny. Supports 100 languages."
    case .whisperSmall: "Best Whisper model. Similar size to Parakeet, but more languages."
    case .parakeetV2: "Top English accuracy among all models. English only."
    case .parakeetV3: "Best overall model. 25 languages with top-tier accuracy and auto-detection."
    case .moonshineTiny: "Smallest model available. English only, basic accuracy."
    case .moonshineBase: "Small English model. Better than Moonshine Tiny, no streaming."
    case .moonshineTinyStreaming: "Smallest streaming model. Real-time English with basic accuracy."
    case .moonshineSmallStreaming: "Compact streaming model. Good English accuracy at a small size."
    case .moonshineMediumStreaming: "Best streaming accuracy, close to Parakeet. English only."
    }
  }

  var downloadSizeMB: Int {
    switch self {
    case .whisperTiny: 69
    case .whisperBase: 132
    case .whisperSmall: 445
    case .parakeetV2: 450
    case .parakeetV3: 477
    case .moonshineTiny: 29
    case .moonshineBase: 107
    case .moonshineTinyStreaming: 33
    case .moonshineSmallStreaming: 105
    case .moonshineMediumStreaming: 202
    }
  }

  var ramRequirementMB: Int {
    switch self {
    case .whisperTiny: 130
    case .whisperBase: 250
    case .whisperSmall: 850
    case .parakeetV2: 860
    case .parakeetV3: 890
    case .moonshineTiny: 60
    case .moonshineBase: 200
    case .moonshineTinyStreaming: 70
    case .moonshineSmallStreaming: 200
    case .moonshineMediumStreaming: 380
    }
  }

  var accuracy: Double {
    switch self {
    case .whisperTiny: 0.35
    case .whisperBase: 0.48
    case .whisperSmall: 0.68
    case .parakeetV2: 0.93
    case .parakeetV3: 0.95
    case .moonshineTiny: 0.38
    case .moonshineBase: 0.52
    case .moonshineTinyStreaming: 0.40
    case .moonshineSmallStreaming: 0.65
    case .moonshineMediumStreaming: 0.80
    }
  }

  var speed: Double {
    switch self {
    case .whisperTiny: 0.98
    case .whisperBase: 0.93
    case .whisperSmall: 0.85
    case .parakeetV2: 0.9
    case .parakeetV3: 0.85
    case .moonshineTiny: 0.97
    case .moonshineBase: 0.94
    case .moonshineTinyStreaming: 0.96
    case .moonshineSmallStreaming: 0.88
    case .moonshineMediumStreaming: 0.78
    }
  }

  var isRecommended: Bool {
    self == .parakeetV3
  }

  var isSupportedOnCurrentDevice: Bool {
    ProcessInfo.processInfo.physicalMemory >= self.ramRequirementMB.megabytesInBytes
  }

  var supportedLanguages: Set<String> {
    switch self {
    case .whisperTiny, .whisperBase, .whisperSmall:
      SpeechLanguages.whisper
    case .parakeetV2:
      SpeechLanguages.englishOnly
    case .parakeetV3:
      SpeechLanguages.parakeetV3
    case .moonshineTiny, .moonshineBase, .moonshineTinyStreaming, .moonshineSmallStreaming, .moonshineMediumStreaming:
      SpeechLanguages.englishOnly
    }
  }

  var languageTagKey: String {
    switch self {
    case .whisperTiny, .whisperBase, .whisperSmall:
      "100 languages"
    case .parakeetV2:
      "English"
    case .parakeetV3:
      "25 languages"
    case .moonshineTiny, .moonshineBase, .moonshineTinyStreaming, .moonshineSmallStreaming, .moonshineMediumStreaming:
      "English"
    }
  }

  var parakeetRepoFolderName: String? {
    switch self {
    case .parakeetV2: "parakeet-tdt-0.6b-v2-coreml"
    case .parakeetV3: "parakeet-tdt-0.6b-v3-coreml"
    default: nil
    }
  }

  var supportsTranslation: Bool {
    switch self.engine {
    case .whisperKit: true
    case .parakeet, .moonshine: false
    }
  }

  var supportsLanguageSelection: Bool {
    switch self.engine {
    case .whisperKit, .parakeet: self.supportedLanguages.count > 1
    case .moonshine: false
    }
  }

  var moonshineModelArch: String? {
    switch self {
    case .moonshineTiny: "tiny"
    case .moonshineBase: "base"
    case .moonshineTinyStreaming: "tinyStreaming"
    case .moonshineSmallStreaming: "smallStreaming"
    case .moonshineMediumStreaming: "mediumStreaming"
    default: nil
    }
  }

  func formattedDownloadSize(locale: Locale = .current) -> String {
    self.downloadSizeMB.formattedAsBytes(locale: locale)
  }

  func formattedRAM(locale: Locale = .current) -> String {
    self.ramRequirementMB.formattedAsBytes(locale: locale)
  }

}

extension Int {

  var megabytesInBytes: UInt64 {
    UInt64(self) * 1_000_000
  }

  func formattedAsBytes(locale: Locale = .current) -> String {
    Int64(self.megabytesInBytes).formatted(.byteCount(style: .file).locale(locale))
  }
}

enum ModelServer {
  static let baseURL = "https://models.sayboard.app"
  static let manifestPath = "/manifest.json"
  static let manifestURL = "\(baseURL)\(manifestPath)"
}

enum ModelDownloadState: Equatable, Sendable {
  case notDownloaded
  case downloading(progress: Double)
  case downloaded
  case error(message: LocalizedStringResource)

  var errorMessage: LocalizedStringResource? {
    guard case .error(let message) = self else { return nil }
    return message
  }
}
