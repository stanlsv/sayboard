import Foundation
import Testing
@testable import Sayboard

@Suite("Choosing the onboarding screen to show")
struct OnboardingProgressTests {

  @Test
  func `a fresh install starts with the languages`() {
    #expect(Self.progress().currentStep == .languages)
  }

  @Test
  func `a passed screen moves on to the next one`() {
    let record = Self.record(passed: [.languages])
    #expect(Self.progress(record).currentStep == .microphone)
  }

  @Test
  func `a usable model skips the languages`() {
    #expect(Self.progress(hasUsableModel: true).currentStep == .microphone)
  }

  @Test
  func `a granted microphone skips its screen`() {
    let record = Self.record(passed: [.languages])
    #expect(Self.progress(record, microphone: true).currentStep == .keyboard)
  }

  @Test
  func `an enabled keyboard skips its screen after the full access relaunch`() {
    let record = Self.record(passed: [.languages, .microphone])
    #expect(Self.progress(record, microphone: true, keyboard: true).currentStep == .keyboardType)
  }

  @Test
  func `the keyboard type is asked even when everything else is ready`() {
    let record = Self.record(passed: [.languages, .microphone, .keyboard])
    let progress = Self.progress(record, microphone: true, keyboard: true, hasUsableModel: true)
    #expect(progress.currentStep == .keyboardType)
  }

  @Test
  func `the writing style is asked after the keyboard type even when everything is ready`() {
    let record = Self.record(passed: [.languages, .microphone, .keyboard, .keyboardType])
    let progress = Self.progress(record, microphone: true, keyboard: true, hasUsableModel: true)
    #expect(progress.currentStep == .writingStyle)
  }

  @Test
  func `stepping forward from the keyboard type shows the writing style`() {
    #expect(Self.progress().nextStep(after: .keyboardType) == .writingStyle)
  }

  @Test
  func `practice waits for a chosen model that is still downloading`() {
    let record = Self.record(passed: Self.beforePractice, chosenModel: Self.chosenModel)
    #expect(Self.progress(record, microphone: true, keyboard: true).currentStep == .practice)
  }

  @Test
  func `practice is skipped without full access`() {
    let record = Self.record(passed: Self.beforePractice, chosenModel: Self.chosenModel)
    #expect(Self.progress(record, microphone: true).currentStep == nil)
  }

  @Test
  func `practice is skipped without the microphone`() {
    let record = Self.record(passed: Self.beforePractice, chosenModel: Self.chosenModel)
    #expect(Self.progress(record, keyboard: true).currentStep == nil)
  }

  @Test
  func `a postponed model skips practice`() {
    let record = Self.record(passed: Self.beforePractice, postponed: [.languages])
    #expect(Self.progress(record, microphone: true, keyboard: true).currentStep == nil)
  }

  @Test
  func `locked dictation skips practice`() {
    let record = Self.record(passed: Self.beforePractice, chosenModel: Self.chosenModel)
    let progress = Self.progress(record, microphone: true, keyboard: true, locked: true)
    #expect(progress.currentStep == nil)
  }

  @Test
  func `every passed screen finishes the onboarding`() {
    let record = Self.record(passed: Set(OnboardingStep.allCases))
    #expect(Self.progress(record).currentStep == nil)
  }

  @Test
  func `a walkthrough shows screens whose setting is already done`() {
    var record = Self.record(passed: [.languages])
    record.isWalkthrough = true
    let progress = Self.progress(record, microphone: true, keyboard: true, hasUsableModel: true)
    #expect(progress.currentStep == .microphone)
  }

  @Test
  func `stepping forward after going back shows the next screen again`() {
    let record = Self.record(passed: Self.beforePractice)
    #expect(Self.progress(record).nextStep(after: .microphone) == .keyboard)
  }

  @Test
  func `stepping forward skips a screen whose setting is done`() {
    let record = Self.record(passed: [.languages])
    #expect(Self.progress(record, microphone: true).nextStep(after: .languages) == .keyboard)
  }

  @Test
  func `stepping forward from the last screen finishes`() {
    #expect(Self.progress().nextStep(after: .practice) == nil)
  }

  @Test
  func `passing a screen can mark it postponed`() {
    var record = OnboardingRecord()
    record.pass(.keyboard, postponed: true)
    record.pass(.microphone)
    #expect(record.passedSteps == [.keyboard, .microphone])
    #expect(record.postponedSteps == [.keyboard])
  }

  @Test
  func `a saved record comes back from a new store`() throws {
    let defaults = try Self.makeDefaults()
    var record = Self.record(passed: [.languages], postponed: [.languages], chosenModel: Self.chosenModel)
    record.isWalkthrough = true
    OnboardingRecordStore(defaults: defaults).save(record)
    #expect(OnboardingRecordStore(defaults: defaults).load() == record)
  }

  @Test
  func `an unreadable record starts fresh`() throws {
    let defaults = try Self.makeDefaults()
    defaults.set(Data("not json".utf8), forKey: SharedKey.onboardingRecord)
    #expect(OnboardingRecordStore(defaults: defaults).load() == OnboardingRecord())
  }

  @Test
  func `a record saved before a field existed still loads`() throws {
    let defaults = try Self.makeDefaults()
    defaults.set(
      Data(#"{"passedSteps":["languages"],"chosenModel":"parakeet-tdt-0.6b-v3"}"#.utf8),
      forKey: SharedKey.onboardingRecord,
    )
    let record = OnboardingRecordStore(defaults: defaults).load()
    #expect(record.passedSteps == [.languages])
    #expect(record.chosenModel == "parakeet-tdt-0.6b-v3")
  }

  @Test
  func `a record naming a screen that no longer exists keeps the rest`() throws {
    let defaults = try Self.makeDefaults()
    let json = #"{"passedSteps":["languages","ai"],"postponedSteps":["ai","keyboard"],"isWalkthrough":false}"#
    defaults.set(Data(json.utf8), forKey: SharedKey.onboardingRecord)
    let record = OnboardingRecordStore(defaults: defaults).load()
    #expect(record.passedSteps == [.languages])
    #expect(record.postponedSteps == [.keyboard])
  }

  @Test
  func `a done item stops being postponed and the others stay`() throws {
    let defaults = try Self.makeDefaults()
    let store = OnboardingRecordStore(defaults: defaults)
    store.save(Self.record(passed: [.languages], postponed: [.languages, .microphone, .keyboard]))
    store.forgetFinishedPostponements(SetupChecklist(
      microphoneGranted: true,
      keyboardAdded: true,
      fullAccessGranted: false,
      hasUsableModel: true,
    ))
    #expect(store.load().postponedSteps == [.keyboard])
  }

  @Test
  func `the keyboard stops being postponed once it has Full Access`() throws {
    let defaults = try Self.makeDefaults()
    let store = OnboardingRecordStore(defaults: defaults)
    store.save(Self.record(passed: [.keyboard], postponed: [.keyboard]))
    store.forgetFinishedPostponements(SetupChecklist(
      microphoneGranted: false,
      keyboardAdded: true,
      fullAccessGranted: true,
      hasUsableModel: false,
    ))
    #expect(store.load().postponedSteps.isEmpty)
  }

  @Test
  func `the step indicator counts only the screens this run shows`() {
    let progress = Self.progress(microphone: true, keyboard: true, hasUsableModel: true)
    #expect(progress.shownSteps(current: .keyboardType) == [.keyboardType, .writingStyle, .practice])
  }

  @Test
  func `a screen already passed keeps its place in the count`() {
    let record = Self.record(passed: [.languages, .microphone], chosenModel: Self.chosenModel)
    let progress = Self.progress(record, microphone: true, keyboard: true)
    let steps = progress.shownSteps(current: .keyboardType)
    #expect(steps == [.languages, .microphone, .keyboardType, .writingStyle, .practice])
    #expect(steps.firstIndex(of: .keyboardType) == 2)
  }

  @Test
  func `the walkthrough counts every screen`() {
    var record = Self.record(passed: [], chosenModel: Self.chosenModel)
    record.isWalkthrough = true
    let progress = Self.progress(record, microphone: true, keyboard: true, hasUsableModel: true)
    #expect(progress.shownSteps(current: .languages) == OnboardingStep.allCases)
  }

  private static let chosenModel = "parakeet-v3"
  private static let beforePractice: [OnboardingStep] = [.languages, .microphone, .keyboard, .keyboardType, .writingStyle]

  private static func record(
    passed: some Sequence<OnboardingStep>,
    postponed: Set<OnboardingStep> = [],
    chosenModel: String? = nil,
  ) -> OnboardingRecord {
    var record = OnboardingRecord()
    record.passedSteps = Set(passed)
    record.postponedSteps = postponed
    record.chosenModel = chosenModel
    return record
  }

  private static func progress(
    _ record: OnboardingRecord = OnboardingRecord(),
    microphone: Bool = false,
    keyboard: Bool = false,
    hasUsableModel: Bool = false,
    locked: Bool = false,
  ) -> OnboardingProgress {
    OnboardingProgress(
      record: record,
      microphoneGranted: microphone,
      keyboardReady: keyboard,
      hasUsableModel: hasUsableModel,
      isDictationLocked: locked,
    )
  }

  private static func makeDefaults() throws -> UserDefaults {
    let suiteName = "app.sayboard.tests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
  }
}

@Suite("Recognizing an install that predates the onboarding")
struct EstablishedInstallTests {

  @Test
  func `an install with a model but no onboarding record counts as set up`() {
    #expect(OnboardingGate.marksCompleteForEstablishedInstall(hasRecord: false, hasModel: true, hasHistory: false))
  }

  @Test
  func `history alone also counts`() {
    #expect(OnboardingGate.marksCompleteForEstablishedInstall(hasRecord: false, hasModel: false, hasHistory: true))
  }

  @Test
  func `a first run interrupted after the model downloaded keeps its onboarding`() {
    #expect(!OnboardingGate.marksCompleteForEstablishedInstall(hasRecord: true, hasModel: true, hasHistory: true))
  }

  @Test
  func `a fresh install is left alone`() {
    #expect(!OnboardingGate.marksCompleteForEstablishedInstall(hasRecord: false, hasModel: false, hasHistory: false))
  }
}
