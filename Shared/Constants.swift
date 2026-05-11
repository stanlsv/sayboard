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
  static let keyboardRequestedDictationAt = "keyboardRequestedDictationAt"
  static let appLanguage = "appLanguage"
  static let retentionPolicy = "retentionPolicy"
  static let isSessionActive = "isSessionActive"
  static let mainAppHeartbeat = "mainAppHeartbeat"
  static let sessionAutoStopPolicy = "sessionAutoStopPolicy"
  static let whisperKitModelPath = "whisperKitModelPath"
  static let hostBundleId = "hostBundleId"
  static let downloadInProgressVariants = "downloadInProgressVariants"
  static let downloadStartedAt = "downloadStartedAt"
  static let preferredLanguagesPerVariant = "preferredLanguagesPerVariant"
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
  static let showGlobeKey = "showGlobeKey"
  static let needsInputModeSwitchKey = "needsInputModeSwitchKey"
  static let alsoCopyToClipboard = "alsoCopyToClipboard"
  static let keyboardKind = "keyboardKind"
  static let keyboardHapticsEnabled = "keyboardHapticsEnabled"
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
  static let supported: Set = [
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
