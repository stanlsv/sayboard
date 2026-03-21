import Foundation

// MARK: - SharedSettings

// SharedSettings -- Read/write settings via App Group UserDefaults

struct SharedSettings {

  // MARK: Lifecycle

  init() {
    self.defaults = AppGroup.sharedDefaults ?? .standard
  }

  // MARK: Internal

  var selectedVariant: ModelVariant {
    get {
      guard
        let raw = defaults.string(forKey: SharedKey.selectedVariant),
        let variant = ModelVariant(rawValue: raw)
      else {
        return .whisperSmall
      }
      return variant
    }
    nonmutating set { defaults.set(newValue.rawValue, forKey: SharedKey.selectedVariant) }
  }

  var isRecording: Bool {
    get { self.defaults.bool(forKey: SharedKey.isRecording) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.isRecording) }
  }

  var keyboardRequestedDictation: Bool {
    get { self.defaults.bool(forKey: SharedKey.keyboardRequestedDictation) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.keyboardRequestedDictation) }
  }

  var isSessionActive: Bool {
    get { self.defaults.bool(forKey: SharedKey.isSessionActive) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.isSessionActive) }
  }

  var sessionAutoStopPolicy: SessionAutoStopPolicy {
    get {
      guard
        let raw = defaults.string(forKey: SharedKey.sessionAutoStopPolicy),
        let policy = SessionAutoStopPolicy(rawValue: raw)
      else {
        return .fiveMinutes
      }
      return policy
    }
    nonmutating set { defaults.set(newValue.rawValue, forKey: SharedKey.sessionAutoStopPolicy) }
  }

  var hostBundleId: String? {
    get { self.defaults.string(forKey: SharedKey.hostBundleId) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.hostBundleId) }
  }

  var retentionPolicy: HistoryRetentionPolicy {
    get {
      guard
        let raw = defaults.string(forKey: SharedKey.retentionPolicy),
        let policy = HistoryRetentionPolicy(rawValue: raw)
      else {
        return .forever
      }
      return policy
    }
    nonmutating set { defaults.set(newValue.rawValue, forKey: SharedKey.retentionPolicy) }
  }

  var downloadInProgressVariants: Set<ModelVariant> {
    get {
      guard let rawValues = defaults.stringArray(forKey: SharedKey.downloadInProgressVariants) else {
        return []
      }
      return Set(rawValues.compactMap { ModelVariant(rawValue: $0) })
    }
    nonmutating set {
      if newValue.isEmpty {
        defaults.removeObject(forKey: SharedKey.downloadInProgressVariants)
      } else {
        defaults.set(newValue.map(\.rawValue), forKey: SharedKey.downloadInProgressVariants)
      }
    }
  }

  var hasUsableModel: Bool {
    get { self.defaults.bool(forKey: SharedKey.hasUsableModel) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.hasUsableModel) }
  }

  var audioLevel: Float {
    get { self.defaults.float(forKey: SharedKey.audioLevel) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.audioLevel) }
  }

  var isMicrophoneAuthorized: Bool {
    get { self.defaults.bool(forKey: SharedKey.isMicrophoneAuthorized) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.isMicrophoneAuthorized) }
  }

  var hasFullAccess: Bool {
    get { self.defaults.bool(forKey: SharedKey.hasFullAccess) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.hasFullAccess) }
  }

  var isModelLoading: Bool {
    get { self.defaults.bool(forKey: SharedKey.isModelLoading) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.isModelLoading) }
  }

  var useCustomSpaceBar: Bool {
    get { self.defaults.bool(forKey: SharedKey.useCustomSpaceBar) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.useCustomSpaceBar) }
  }

  var isTranslationMode: Bool {
    get { self.defaults.bool(forKey: SharedKey.isTranslationMode) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.isTranslationMode) }
  }

  var defaultWritingStyle: WritingStyle {
    get {
      guard
        let raw = defaults.string(forKey: SharedKey.defaultWritingStyle),
        let style = WritingStyle(rawValue: raw)
      else {
        return .formal
      }
      return style
    }
    nonmutating set { defaults.set(newValue.rawValue, forKey: SharedKey.defaultWritingStyle) }
  }

  var downloadStartedAt: Date? {
    get {
      let interval = self.defaults.double(forKey: SharedKey.downloadStartedAt)
      return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }
    nonmutating set {
      if let newValue {
        defaults.set(newValue.timeIntervalSince1970, forKey: SharedKey.downloadStartedAt)
      } else {
        defaults.removeObject(forKey: SharedKey.downloadStartedAt)
      }
    }
  }

  var selectedLLMVariant: LLMModelVariant {
    get {
      guard
        let raw = defaults.string(forKey: SharedKey.selectedLLMVariant),
        let variant = LLMModelVariant(rawValue: raw)
      else {
        return .qwen3Small
      }
      return variant
    }
    nonmutating set { defaults.set(newValue.rawValue, forKey: SharedKey.selectedLLMVariant) }
  }

  var llmDownloadInProgressVariants: Set<LLMModelVariant> {
    get {
      guard let rawValues = defaults.stringArray(forKey: SharedKey.llmDownloadInProgressVariants) else {
        return []
      }
      return Set(rawValues.compactMap { LLMModelVariant(rawValue: $0) })
    }
    nonmutating set {
      if newValue.isEmpty {
        defaults.removeObject(forKey: SharedKey.llmDownloadInProgressVariants)
      } else {
        defaults.set(newValue.map(\.rawValue), forKey: SharedKey.llmDownloadInProgressVariants)
      }
    }
  }

  var hasUsableLLMModel: Bool {
    get { self.defaults.bool(forKey: SharedKey.hasUsableLLMModel) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.hasUsableLLMModel) }
  }

  var isLLMProcessing: Bool {
    get { self.defaults.bool(forKey: SharedKey.isLLMProcessing) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.isLLMProcessing) }
  }

  var llmEnabled: Bool {
    get { self.defaults.bool(forKey: SharedKey.llmEnabled) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.llmEnabled) }
  }

  var defaultLLMActionSelection: LLMActionSelection {
    get {
      if let data = defaults.data(forKey: SharedKey.defaultLLMActionSelection) {
        if let selection = try? JSONDecoder().decode(LLMActionSelection.self, from: data) {
          return selection
        }
      }
      // Migrate from old key
      if
        let raw = defaults.string(forKey: SharedKey.defaultLLMAction),
        let action = LLMAction(rawValue: raw)
      {
        let migrated = LLMActionSelection.preset(action)
        let data = try? JSONEncoder().encode(migrated)
        self.defaults.set(data, forKey: SharedKey.defaultLLMActionSelection)
        self.defaults.removeObject(forKey: SharedKey.defaultLLMAction)
        return migrated
      }
      return .none
    }
    nonmutating set {
      let data = try? JSONEncoder().encode(newValue)
      defaults.set(data, forKey: SharedKey.defaultLLMActionSelection)
      defaults.removeObject(forKey: SharedKey.defaultLLMAction)
    }
  }

  var llmCustomPrompts: [LLMCustomPrompt] {
    get {
      guard let data = defaults.data(forKey: SharedKey.llmCustomPrompts) else { return [] }
      return (try? JSONDecoder().decode([LLMCustomPrompt].self, from: data)) ?? []
    }
    nonmutating set {
      let data = try? JSONEncoder().encode(newValue)
      defaults.set(data, forKey: SharedKey.llmCustomPrompts)
    }
  }

  var longPressLLMAction: LLMActionSelection {
    get {
      guard let data = defaults.data(forKey: SharedKey.longPressLLMAction) else { return .none }
      return (try? JSONDecoder().decode(LLMActionSelection.self, from: data)) ?? .none
    }
    nonmutating set {
      let data = try? JSONEncoder().encode(newValue)
      defaults.set(data, forKey: SharedKey.longPressLLMAction)
    }
  }

  var disabledLLMActions: Set<LLMAction> {
    get {
      guard let rawValues = defaults.stringArray(forKey: SharedKey.disabledLLMActions) else {
        return []
      }
      return Set(rawValues.compactMap { LLMAction(rawValue: $0) })
    }
    nonmutating set {
      if newValue.isEmpty {
        defaults.removeObject(forKey: SharedKey.disabledLLMActions)
      } else {
        defaults.set(newValue.map(\.rawValue), forKey: SharedKey.disabledLLMActions)
      }
    }
  }

  var dictationSessionToken: String? {
    get { self.defaults.string(forKey: SharedKey.dictationSessionToken) }
    nonmutating set { defaults.set(newValue, forKey: SharedKey.dictationSessionToken) }
  }

  var snippets: [Snippet] {
    get {
      guard let data = defaults.data(forKey: SharedKey.snippets) else {
        return []
      }
      return (try? JSONDecoder().decode([Snippet].self, from: data)) ?? []
    }
    nonmutating set {
      let data = try? JSONEncoder().encode(newValue)
      defaults.set(data, forKey: SharedKey.snippets)
    }
  }

  /// Flush the in-memory UserDefaults cache so the next read comes from disk.
  /// Required for cross-process reads where another process has written.
  func synchronize() {
    self.defaults.synchronize()
  }

  // MARK: Private

  private let defaults: UserDefaults
}
