
import SwiftUI

struct OnboardingView: View {

  static let stepAnimation = Animation.easeInOut(duration: 0.35)

  let onFinish: () -> Void

  var body: some View {
    NavigationStack {
      ZStack {
        if let step = self.step {
          self.screen(for: step)
            .id(step)
            .transition(.push(from: self.isGoingBack ? .leading : .trailing))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color(.systemGroupedBackground).ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { self.toolbar }
      .onChange(of: self.isGoingBack) { self.showPendingStep() }
    }
    .background(ChosenModelActivator(variant: self.chosenModel))
    .onAppear(perform: self.start)
  }

  @EnvironmentObject private var permissionService: PermissionService
  @AppStorage(SharedKey.hasUsableModel, store: UserDefaults(suiteName: AppGroup.identifier))
  private var hasUsableModel = false
  @State private var record = OnboardingRecord()
  @State private var step: OnboardingStep?
  @State private var history = [OnboardingStep]()
  @State private var isGoingBack = false
  @State private var pendingStep: OnboardingStep?
  @State private var languageDraft = OnboardingLanguageDraft()

  private let store = OnboardingRecordStore()

  private var chosenModel: ModelVariant? {
    self.record.chosenModel.flatMap(ModelVariant.init(rawValue:))
  }

  private var progress: OnboardingProgress {
    OnboardingProgress(
      record: self.record,
      microphoneGranted: self.permissionService.microphoneState == .granted,
      keyboardReady: self.permissionService.isKeyboardAdded && self.permissionService.hasFullAccess,
      hasUsableModel: self.hasUsableModel,
      isDictationLocked: SharedSettings().isDictationLocked,
    )
  }

  private var showsBack: Bool {
    guard !self.history.isEmpty else { return false }
    return self.step != .microphone || self.permissionService.microphoneState != .undetermined
  }

  private var showsLater: Bool {
    self.step == .languages || (self.step == .keyboard && !self.progress.keyboardReady)
  }

  private var stepNumbers: (current: Int, total: Int)? {
    let steps = self.progress.shownSteps(current: self.step)
    guard let step = self.step, let index = steps.firstIndex(of: step) else { return nil }
    return (index + 1, steps.count)
  }

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    if self.showsBack {
      ToolbarItem(placement: .topBarLeading) {
        Button(action: self.goBack) {
          Image(systemName: "chevron.left")
        }
        .accessibilityLabel(Text("Back"))
      }
    }
    if let numbers = self.stepNumbers {
      ToolbarItem(placement: .principal) {
        OnboardingStepIndicator(current: numbers.current, total: numbers.total)
      }
    }
    if self.showsLater {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Later") { self.postponeCurrentStep() }
      }
    }
  }

  @ViewBuilder
  private func screen(for step: OnboardingStep) -> some View {
    switch step {
    case .languages:
      OnboardingLanguagesView(
        previousChoice: self.chosenModel,
        draft: self.$languageDraft,
      ) { variant in
        self.record.chosenModel = variant.rawValue
        self.pass(.languages)
      }

    case .microphone:
      OnboardingMicrophoneView(
        onContinue: { self.pass(.microphone) },
        onContinueWithout: { self.pass(.microphone, postponed: true) },
      )

    case .keyboard:
      OnboardingKeyboardView(advancesWhenReady: !self.isGoingBack) { self.pass(.keyboard) }

    case .keyboardType:
      OnboardingKeyboardTypeView { self.pass(.keyboardType) }

    case .writingStyle:
      OnboardingWritingStyleView(isLast: self.progress.nextStep(after: .writingStyle) == nil) { self.pass(.writingStyle) }

    case .practice:
      OnboardingPracticeView(model: self.chosenModel ?? SharedSettings().selectedVariant) { self.pass(.practice) }
    }
  }

  private func start() {
    self.permissionService.refreshAll()
    self.record = self.store.load()
    guard let step = self.progress.currentStep else {
      self.onFinish()
      return
    }
    self.step = step
  }

  private func pass(_ step: OnboardingStep, postponed: Bool = false) {
    guard step == self.step, self.pendingStep == nil else { return }
    self.record.pass(step, postponed: postponed)
    self.store.save(self.record)
    guard let next = self.progress.nextStep(after: step) else {
      self.onFinish()
      return
    }
    self.history.append(step)
    self.show(next, goingBack: false)
  }

  private func postponeCurrentStep() {
    guard let step = self.step else { return }
    self.pass(step, postponed: true)
  }

  private func goBack() {
    guard let previous = self.history.popLast() else { return }
    self.show(previous, goingBack: true)
  }

  private func show(_ next: OnboardingStep, goingBack: Bool) {
    guard goingBack != self.isGoingBack else {
      withAnimation(Self.stepAnimation) { self.step = next }
      return
    }
    self.pendingStep = next
    self.isGoingBack = goingBack
  }

  private func showPendingStep() {
    guard let next = self.pendingStep else { return }
    self.pendingStep = nil
    withAnimation(Self.stepAnimation) { self.step = next }
  }

}

private struct ChosenModelActivator: View {

  let variant: ModelVariant?

  var body: some View {
    Color.clear
      .onAppear(perform: self.activateIfReady)
      .onChange(of: self.variant) { self.activateIfReady() }
      .onChange(of: self.isReady) { self.activateIfReady() }
      .onChange(of: self.speechService.isStopping) { self.activateIfReady() }
  }

  @EnvironmentObject private var downloadService: ModelDownloadService
  @EnvironmentObject private var speechService: SpeechRecognitionService

  private var isReady: Bool {
    self.variant.map { self.downloadService.isDownloaded($0) } ?? false
  }

  private func activateIfReady() {
    guard
      let variant = self.variant,
      self.downloadService.isDownloaded(variant),
      self.downloadService.selectedVariant != variant,
      !self.speechService.isRecording,
      !self.speechService.isStopping
    else { return }
    self.downloadService.selectVariant(variant)
  }
}
