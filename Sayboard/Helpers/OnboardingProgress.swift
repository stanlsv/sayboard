
import Foundation

enum OnboardingStep: String, CaseIterable, Codable, Sendable {
  case languages
  case microphone
  case keyboard
  case keyboardType
  case writingStyle
  case practice
}

struct OnboardingRecord: Codable, Equatable, Sendable {

  var passedSteps = Set<OnboardingStep>()
  var postponedSteps = Set<OnboardingStep>()
  var chosenModel: String?
  var isWalkthrough = false

  mutating func pass(_ step: OnboardingStep, postponed: Bool = false) {
    self.passedSteps.insert(step)
    if postponed {
      self.postponedSteps.insert(step)
    } else {
      self.postponedSteps.remove(step)
    }
  }
}

extension OnboardingRecord {

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init()
    self.passedSteps = Self.steps(in: container, forKey: .passedSteps)
    self.postponedSteps = Self.steps(in: container, forKey: .postponedSteps)
    self.chosenModel = try container.decodeIfPresent(String.self, forKey: .chosenModel)
    self.isWalkthrough = try container.decodeIfPresent(Bool.self, forKey: .isWalkthrough) ?? false
  }

  private static func steps(in container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Set<OnboardingStep> {
    let rawValues = (try? container.decodeIfPresent([String].self, forKey: key)) ?? []
    return Set(rawValues.compactMap(OnboardingStep.init(rawValue:)))
  }
}

struct OnboardingProgress: Equatable, Sendable {

  let record: OnboardingRecord
  let microphoneGranted: Bool
  let keyboardReady: Bool
  let hasUsableModel: Bool
  let isDictationLocked: Bool

  var currentStep: OnboardingStep? {
    OnboardingStep.allCases.first { !self.record.passedSteps.contains($0) && !self.isSkipped($0) }
  }

  func shownSteps(current: OnboardingStep?) -> [OnboardingStep] {
    OnboardingStep.allCases.filter {
      $0 == current || self.record.passedSteps.contains($0) || !self.isSkipped($0)
    }
  }

  func nextStep(after step: OnboardingStep) -> OnboardingStep? {
    let later = OnboardingStep.allCases.drop { $0 != step }.dropFirst()
    return later.first { !self.isSkipped($0) }
  }

  private var canPractice: Bool {
    let hasModel = self.hasUsableModel || (self.record.chosenModel != nil && !self.record.postponedSteps.contains(.languages))
    return self.microphoneGranted && self.keyboardReady && hasModel && !self.isDictationLocked
  }

  private func isSkipped(_ step: OnboardingStep) -> Bool {
    if self.record.isWalkthrough { return false }
    switch step {
    case .languages: return self.hasUsableModel
    case .microphone: return self.microphoneGranted
    case .keyboard: return self.keyboardReady
    case .practice: return !self.canPractice
    case .keyboardType, .writingStyle: return false
    }
  }
}

struct OnboardingRecordStore {

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func load() -> OnboardingRecord {
    guard let data = self.defaults.data(forKey: SharedKey.onboardingRecord) else { return OnboardingRecord() }
    do {
      return try JSONDecoder().decode(OnboardingRecord.self, from: data)
    } catch {
      return OnboardingRecord()
    }
  }

  func save(_ record: OnboardingRecord) {
    do {
      try self.defaults.set(JSONEncoder().encode(record), forKey: SharedKey.onboardingRecord)
    } catch { }
  }

  func forgetFinishedPostponements(_ checklist: SetupChecklist) {
    var record = self.load()
    let before = record.postponedSteps
    if checklist.microphoneGranted { record.postponedSteps.remove(.microphone) }
    if checklist.keyboardAdded, checklist.fullAccessGranted { record.postponedSteps.remove(.keyboard) }
    if checklist.hasUsableModel { record.postponedSteps.remove(.languages) }
    if record.postponedSteps != before { self.save(record) }
  }

  private let defaults: UserDefaults
}

enum OnboardingGate {

  static func marksCompleteForEstablishedInstall(hasRecord: Bool, hasModel: Bool, hasHistory: Bool) -> Bool {
    guard !hasRecord else { return false }
    return hasModel || hasHistory
  }
}
