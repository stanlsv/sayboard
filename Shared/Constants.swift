import Foundation

// MARK: - AppGroup

enum AppGroup {
  static let identifier = "group.app.sayboard.shared"

  static var containerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
  }

  static var sharedDefaults: UserDefaults? {
    UserDefaults(suiteName: identifier)
  }
}

// MARK: - DeepLink

enum DeepLink {
  static let scheme = "sayboard"
  static let dictateHost = "dictate"
  static let stopHost = "stop"
  static let settingsHost = "settings"
  static let modelsHost = "models"
  static let llmModelsHost = "llm-models"
  static let setupMicHost = "setup-mic"

  static var dictateURL: URL? {
    URL(string: "\(scheme)://\(dictateHost)")
  }

  static var settingsURL: URL? {
    URL(string: "\(scheme)://\(settingsHost)")
  }

  static var modelsURL: URL? {
    URL(string: "\(scheme)://\(modelsHost)")
  }

  static var llmModelsURL: URL? {
    URL(string: "\(scheme)://\(llmModelsHost)")
  }

  static var setupMicURL: URL? {
    URL(string: "\(scheme)://\(setupMicHost)")
  }
}

// MARK: - SharedKey

enum SharedKey {
  static let transcribedText = "transcribedText"
  static let isRecording = "isRecording"
  static let selectedVariant = "selectedVariant"
  static let keyboardRequestedDictation = "keyboardRequestedDictation"
  static let appLanguage = "appLanguage"
  static let retentionPolicy = "retentionPolicy"
  static let isSessionActive = "isSessionActive"
  static let sessionAutoStopPolicy = "sessionAutoStopPolicy"
  static let whisperKitModelPath = "whisperKitModelPath"
  static let hostBundleId = "hostBundleId"
  static let downloadInProgressVariants = "downloadInProgressVariants"
  static let downloadStartedAt = "downloadStartedAt"
  static let hasUsableModel = "hasUsableModel"
  static let audioLevel = "audioLevel"
  static let isMicrophoneAuthorized = "isMicrophoneAuthorized"
  static let hasCompletedOnboarding = "hasCompletedOnboarding"
  static let hasFullAccess = "hasFullAccess"
  static let isModelLoading = "isModelLoading"
  static let useCustomSpaceBar = "useCustomSpaceBar"
  static let isTranslationMode = "isTranslationMode"
  static let appWritingStyles = "appWritingStyles"
  static let defaultWritingStyle = "defaultWritingStyle"
  static let selectedLLMVariant = "selectedLLMVariant"
  static let hasUsableLLMModel = "hasUsableLLMModel"
  static let llmDownloadInProgressVariants = "llmDownloadInProgressVariants"
  static let isLLMProcessing = "isLLMProcessing"
  static let llmEnabled = "llmEnabled"
  static let defaultLLMAction = "defaultLLMAction"
  static let defaultLLMActionSelection = "defaultLLMActionSelection"
  static let llmCustomPrompts = "llmCustomPrompts"
  static let longPressLLMAction = "longPressLLMAction"
  static let disabledLLMActions = "disabledLLMActions"
  static let snippets = "snippets"
  static let dictationSessionToken = "dictationSessionToken"
}

// MARK: - HistoryRetentionPolicy

enum HistoryRetentionPolicy: String, CaseIterable, Sendable {
  case never
  case last5
  case last25
  case last50
  case last100
  case last500
  case past24Hours
  case pastWeek
  case pastMonth
  case forever

  // MARK: Internal

  var displayNameKey: String {
    switch self {
    case .never: "Never"
    case .last5: "Last 5 recordings"
    case .last25: "Last 25 recordings"
    case .last50: "Last 50 recordings"
    case .last100: "Last 100 recordings"
    case .last500: "Last 500 recordings"
    case .past24Hours: "Past 24 hours"
    case .pastWeek: "Past week"
    case .pastMonth: "Past month"
    case .forever: "Forever"
    }
  }

  var shortDisplayNameKey: String {
    switch self {
    case .never: "Never"
    case .last5: "Last 5"
    case .last25: "Last 25"
    case .last50: "Last 50"
    case .last100: "Last 100"
    case .last500: "Last 500"
    case .past24Hours: "24 hours"
    case .pastWeek: "1 week"
    case .pastMonth: "1 month"
    case .forever: "Forever"
    }
  }
}

// MARK: - DarwinNotificationName

enum DarwinNotificationName {
  static let transcriptionReady = "app.sayboard.transcriptionReady"
  static let dictationStarted = "app.sayboard.dictationStarted"
  static let dictationStopped = "app.sayboard.dictationStopped"
  static let requestStartDictation = "app.sayboard.requestStartDictation"
  static let requestStopDictation = "app.sayboard.requestStopDictation"
  static let sessionStarted = "app.sayboard.sessionStarted"
  static let sessionEnded = "app.sayboard.sessionEnded"
  static let requestSessionStatus = "app.sayboard.requestSessionStatus"
  static let fullAccessChanged = "app.sayboard.fullAccessChanged"
  static let modelLoadingFailed = "app.sayboard.modelLoadingFailed"
  static let requestLLMProcessing = "app.sayboard.requestLLMProcessing"
  static let llmProcessingStarted = "app.sayboard.llmProcessingStarted"
  static let llmProcessingComplete = "app.sayboard.llmProcessingComplete"
  static let llmProcessingFailed = "app.sayboard.llmProcessingFailed"
}

// MARK: - SessionAutoStopPolicy

enum SessionAutoStopPolicy: String, CaseIterable, Sendable {
  case never
  case fiveMinutes
  case fifteenMinutes
  case thirtyMinutes
  case oneHour
  case twoHours
  case fourHours
  case eightHours
  case twelveHours

  // MARK: Internal

  var displayNameKey: String {
    switch self {
    case .never: "Never"
    case .fiveMinutes: "5 minutes"
    case .fifteenMinutes: "15 minutes"
    case .thirtyMinutes: "30 minutes"
    case .oneHour: "1 hour"
    case .twoHours: "2 hours"
    case .fourHours: "4 hours"
    case .eightHours: "8 hours"
    case .twelveHours: "12 hours"
    }
  }

  var timeoutSeconds: TimeInterval? {
    switch self {
    case .never: nil
    case .fiveMinutes: 300
    case .fifteenMinutes: 900
    case .thirtyMinutes: 1_800
    case .oneHour: 3_600
    case .twoHours: 7_200
    case .fourHours: 14_400
    case .eightHours: 28_800
    case .twelveHours: 43_200
    }
  }
}

// MARK: - InternalNotification

extension Notification.Name {
  static let appLanguageChangeRequested = Notification.Name("app.sayboard.appLanguageChangeRequested")
  static let dictationFailedNoModel = Notification.Name("app.sayboard.dictationFailedNoModel")
  static let dictationFailedNoMic = Notification.Name("app.sayboard.dictationFailedNoMic")
}

// MARK: - AppLanguageConfig

enum AppLanguageConfig {
  static let supported: Set<String> = [
    "en",
    "ru",
    "cs",
    "da",
    "de",
    "el",
    "es",
    "fi",
    "fr",
    "hi",
    "hu",
    "it",
    "ja",
    "ko",
    "nl",
    "no",
    "pl",
    "pt",
    "ro",
    "sk",
    "sv",
    "tr",
    "uk",
    "zh",
  ]
  static let fallback = "en"

  static func resolveLanguage(from preferredLanguages: [String]) -> String {
    let systemLanguage = preferredLanguages.first
      .flatMap { Locale(identifier: $0).language.languageCode?.identifier }
      ?? self.fallback
    return self.supported.contains(systemLanguage) ? systemLanguage : self.fallback
  }
}

// MARK: - AnimationSpeed

enum AnimationSpeed {
  /// Global animation speed multiplier (1.0 = default, 2.0 = 2x faster)
  static let globalMultiplier: Float = 1.5
}

// MARK: - STTEngine

enum STTEngine: String, Codable, Sendable {
  case whisperKit
  case parakeet
  case moonshine

  // MARK: Internal

  var sectionTitle: String {
    switch self {
    case .whisperKit: "Whisper"
    case .parakeet: "Parakeet"
    case .moonshine: "Moonshine"
    }
  }
}

// MARK: - ModelVariant

enum ModelVariant: String, CaseIterable, Identifiable, Codable, Sendable {
  // WhisperKit
  case whisperTiny = "openai_whisper-tiny"
  case whisperBase = "openai_whisper-base"
  case whisperSmall = "openai_whisper-small"
  // Parakeet (FluidAudio)
  case parakeetV2 = "parakeet-tdt-0.6b-v2"
  case parakeetV3 = "parakeet-tdt-0.6b-v3"
  // Moonshine (ONNX Runtime)
  case moonshineTiny = "moonshine-tiny-en"
  case moonshineBase = "moonshine-base-en"
  case moonshineTinyStreaming = "moonshine-tiny-streaming-en"
  case moonshineSmallStreaming = "moonshine-small-streaming-en"
  case moonshineMediumStreaming = "moonshine-medium-streaming-en"

  // MARK: Internal

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
    case .parakeetV3: 466
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

  /// Whether the current device has enough RAM for this model.
  var isSupportedOnCurrentDevice: Bool {
    ProcessInfo.processInfo.physicalMemory >= UInt64(self.ramRequirementMB) * 1024 * 1024
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

  /// The folder name inside the extracted zip for Parakeet models (matches HuggingFace repo structure).
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

  /// The Moonshine model architecture for this variant, or nil if not a Moonshine model.
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

// MARK: - Int + Byte Formatting

extension Int {
  func formattedAsBytes(locale: Locale = .current) -> String {
    let bytes = Int64(self) * 1_000_000
    return bytes.formatted(.byteCount(style: .file).locale(locale))
  }
}

// MARK: - ModelServer

enum ModelServer {
  static let baseURL = "https://models.sayboard.app"
  static let manifestPath = "/manifest.json"
  static let manifestURL = "\(baseURL)\(manifestPath)"
}

// MARK: - ModelDownloadState

enum ModelDownloadState: Equatable, Sendable {
  case notDownloaded
  case downloading(progress: Double)
  case downloaded
  case error(message: String)
}
