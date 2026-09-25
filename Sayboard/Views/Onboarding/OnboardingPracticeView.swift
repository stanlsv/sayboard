
import SwiftUI

struct OnboardingPracticeView: View {

  let model: ModelVariant
  let onContinue: () -> Void

  var body: some View {
    Group {
      if self.isFieldShown {
        OnboardingPracticeFieldView(
          isSwitchingKeyboard: self.$isSwitchingKeyboard,
          didSucceed: self.didSucceed,
          onContinue: self.onContinue,
        )
      } else {
        self.intro
      }
    }
    .onChange(of: self.speechService.historySaveGeneration) {
      if self.isFieldShown { self.didSucceed = true }
    }
    .onboardingTextEntry(isActive: self.isFieldShown, isPractice: true)
    .sensoryFeedback(.success, trigger: self.didSucceed)
    .task(id: self.isFieldShown) {
      guard self.isFieldShown, (try? await Task.sleep(for: Self.switchLaterDelay)) != nil else { return }
      self.isSwitchOverdue = true
    }
    .toolbar {
      if self.offersLater {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Later", action: self.onContinue)
        }
      }
    }
  }

  private static let sectionSpacing: CGFloat = 22
  private static let switchLaterDelay = Duration.seconds(15)

  @EnvironmentObject private var speechService: SpeechRecognitionService
  @EnvironmentObject private var permissionService: PermissionService
  @AppStorage(SharedKey.hasUsableModel, store: UserDefaults(suiteName: AppGroup.identifier))
  private var hasUsableModel = false
  @State private var isFieldShown = false
  @State private var isSwitchingKeyboard = true
  @State private var didSucceed = false
  @State private var didFailToStart = false
  @State private var isSwitchOverdue = false

  private var offersLater: Bool {
    guard self.isFieldShown else { return !self.canStart || self.didFailToStart }
    if self.isSwitchingKeyboard { return self.isSwitchOverdue }
    return !self.didSucceed
  }

  private var canStart: Bool {
    self.permissionService.microphoneState == .granted
      && self.permissionService.isKeyboardAdded
      && self.permissionService.hasFullAccess
      && self.hasUsableModel
  }

  private var intro: some View {
    OnboardingScreen {
      Spacer(minLength: 0)
      OnboardingHeader(
        title: "Try It Here",
        subtitle: "Your first dictation — right in this field, with your new keyboard",
      )
      if !self.hasUsableModel {
        OnboardingModelStatusView(variant: self.model, alignment: .center)
          .padding(.top, Self.sectionSpacing)
      }
      if self.didFailToStart {
        ModelNoticeRow(text: Text("The microphone didn’t turn on. Try again."))
          .padding(.horizontal, 16)
      }
      Spacer(minLength: 0)
    } actions: {
      OnboardingPrimaryButton(label: Text("Start"), isEnabled: self.canStart, action: self.start)
    }
    .animation(.default, value: self.hasUsableModel)
  }

  private func start() {
    do {
      try self.speechService.session.startSession()
      self.didFailToStart = false
      withAnimation(OnboardingView.stepAnimation) { self.isFieldShown = true }
    } catch {
      self.didFailToStart = true
    }
  }
}

private struct OnboardingPracticeFieldView: View {

  @Binding var isSwitchingKeyboard: Bool

  let didSucceed: Bool
  let onContinue: () -> Void

  var body: some View {
    ZStack {
      if self.isSwitchingKeyboard {
        self.switchScreen
          .transition(.push(from: .trailing))
      }
      self.dictationScreen
        .visualEffect { [isSwitching = self.isSwitchingKeyboard] content, proxy in
          content.offset(x: isSwitching ? proxy.size.width : 0)
        }
        .accessibilityHidden(self.isSwitchingKeyboard)
    }
    .task {
      try? await Task.sleep(for: Self.focusDelay)
      self.isFieldFocused = true
    }
    .task {
      await self.waitForSayboardKeyboard()
    }
    .onChange(of: self.speechService.isRecording) { _, isRecording in
      if isRecording { self.awaitsDictatedText = true }
    }
    .onChange(of: self.speechService.isStopping) { _, isStopping in
      if !isStopping, self.speechService.currentTranscription.isEmpty { self.awaitsDictatedText = false }
    }
    .onChange(of: self.text) {
      guard self.awaitsDictatedText, !self.speechService.isRecording else { return }
      self.awaitsDictatedText = false
      self.isFieldFocused = false
    }
  }

  private static let horizontalPadding: CGFloat = 20
  private static let fieldTopPadding: CGFloat = 20
  private static let compactFieldTopPadding: CGFloat = 12
  private static let compactHeight: CGFloat = 400
  private static let fieldPadding: CGFloat = 14
  private static let fieldCornerRadius: CGFloat = 16
  private static let focusedBorderWidth: CGFloat = 2
  private static let focusDelay = Duration.milliseconds(400)

  @EnvironmentObject private var speechService: SpeechRecognitionService
  @State private var screenHeight = CGFloat.infinity
  @State private var text = ""
  @State private var awaitsDictatedText = false
  @FocusState private var isFieldFocused: Bool

  private var switchScreen: some View {
    OnboardingScreen {
      OnboardingHeader(
        title: "Switch the Keyboard",
        subtitle: "Touch and hold \(Image(systemName: "globe")), then choose Sayboard.",
      )
      KeyboardSwitchTutorialView()
        .padding(.vertical, Self.fieldTopPadding)
    } actions: {
      EmptyView()
    }
    .contentShape(Rectangle())
    .onTapGesture { self.isFieldFocused = true }
  }

  private var dictationScreen: some View {
    OnboardingScreen {
      if self.didSucceed {
        OnboardingHeader(title: "It Works! 🎉", isCompact: self.isCompact)
      } else {
        OnboardingHeader(
          title: "Say Something",
          subtitle: self.isCompact ? nil : "Tap the microphone and start talking. Tap it again when you’re done.",
          isCompact: self.isCompact,
        )
      }
      self.field
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.top, self.isCompact ? Self.compactFieldTopPadding : Self.fieldTopPadding)
    } actions: {
      if self.didSucceed || !self.isCompact {
        OnboardingPrimaryButton(label: Text("Done"), isEnabled: self.didSucceed, action: self.onContinue)
      }
      OnboardingSecondaryButton(title: "Change Keyboard Type", action: self.switchKeyboardType)
    }
    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { self.screenHeight = $0 }
    .animation(OnboardingView.stepAnimation, value: self.isCompact)
  }

  private var isCompact: Bool {
    self.screenHeight < Self.compactHeight
  }

  private var field: some View {
    TextField("Your words will appear here", text: self.$text, axis: .vertical)
      .focused(self.$isFieldFocused)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(Self.fieldPadding)
      .contentShape(RoundedRectangle(cornerRadius: Self.fieldCornerRadius, style: .continuous))
      .onTapGesture { self.isFieldFocused = true }
      .background(
        Color(.secondarySystemGroupedBackground),
        in: RoundedRectangle(cornerRadius: Self.fieldCornerRadius, style: .continuous),
      )
      .overlay {
        RoundedRectangle(cornerRadius: Self.fieldCornerRadius, style: .continuous)
          .strokeBorder(Color.accentColor, lineWidth: self.isFieldFocused ? Self.focusedBorderWidth : 0)
      }
  }

  private func waitForSayboardKeyboard() async {
    let (shown, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    let observer = TranscriptionBridge.observeDarwinNotification(DarwinNotificationName.keyboardShownInPractice) {
      @Sendable in continuation.yield()
    }
    defer { observer.stopObserving() }
    for await _ in shown {
      self.text = ""
      withAnimation(OnboardingView.stepAnimation) { self.isSwitchingKeyboard = false }
      return
    }
  }

  private func switchKeyboardType() {
    let settings = SharedSettings()
    settings.keyboardKind = settings.keyboardKind == .standard ? .extended : .standard
    self.isFieldFocused = false
    Task {
      try? await Task.sleep(for: Self.focusDelay)
      self.isFieldFocused = true
    }
  }
}
