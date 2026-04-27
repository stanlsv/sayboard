import SwiftUI
import UIKit

// MARK: - Keyboard Colors

extension UIColor {
  /// Standard iOS keyboard letter-key background (space bar, letter keys)
  static let keyBackground = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.33, green: 0.33, blue: 0.34, alpha: 1)
      : .white
  }

  static let keyPressedBackground = UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.25, green: 0.25, blue: 0.26, alpha: 1)
      : UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1)
  }
}

// MARK: - KeyboardProxy

struct KeyboardProxy {
  let insertText: (String) -> Void
  let deleteBackward: () -> Void
  let deleteAll: () -> Void
  let advanceToNextInputMode: () -> Void
  let openURL: (URL) -> Void
  let startDictation: () -> Void
  let stopDictation: () -> Void
  let requestLLMProcessing: (LLMAction, UUID?) -> Void
  let adjustTextPosition: (Int) -> Void
  let undoLLM: () -> Void
  let redoLLM: () -> Void
  let setActionBarVisible: (Bool) -> Void
}

// MARK: - SetupBlocker

enum SetupBlocker {
  case fullAccessMissing
  case micDenied
  case noModel

  // MARK: Internal

  var icon: String {
    switch self {
    case .fullAccessMissing: "lock.open"
    case .micDenied: "mic.slash"
    case .noModel: "arrow.down.circle"
    }
  }

  var message: LocalizedStringKey {
    switch self {
    case .fullAccessMissing: "Full Access is disabled. Open the Sayboard app for setup instructions"
    case .micDenied: "Microphone is disabled. Allow Sayboard microphone access to recognize your speech"
    case .noModel: "No speech model yet. Download a speech model to start using voice input"
    }
  }

  var buttonTitle: LocalizedStringKey {
    switch self {
    case .fullAccessMissing: "Open Settings"
    case .micDenied: "Open Settings"
    case .noModel: "Open Models"
    }
  }

  /// Links work only when Full Access is granted.
  /// `.fullAccessMissing` returns `nil` — no tappable button.
  var linkURL: URL? {
    switch self {
    case .fullAccessMissing: nil
    case .micDenied: DeepLink.setupMicURL
    case .noModel: DeepLink.modelsURL
    }
  }
}

// MARK: - RectKeyStyle

struct RectKeyStyle: ButtonStyle {
  var fixedWidth: CGFloat?

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .frame(maxWidth: self.fixedWidth ?? .infinity)
      .frame(width: self.fixedWidth, height: 45)
      .background {
        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
          .fill(Color(configuration.isPressed ? .keyPressedBackground : .keyBackground))
      }
  }
}

// MARK: - CircleKeyStyle

struct CircleKeyStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .frame(width: 106, height: 106)
      .background {
        Circle()
          .fill(Color(configuration.isPressed ? .keyPressedBackground : .keyBackground))
      }
  }
}

// MARK: - KeyboardView

struct KeyboardView: View {

  // MARK: Internal

  let proxy: KeyboardProxy

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    if let blocker = self.activeBlocker {
      BlockerPrompt(blocker: blocker)
    } else if let error = self.keyboardState.llmError {
      LLMErrorPrompt(error: error, keyboardState: self.keyboardState)
    } else {
      VStack(spacing: 0) {
        Color.clear
          .overlay {
            Group {
              let showModelLoading = self.keyboardState.isModelLoading && self.keyboardState.isProcessing
              if showModelLoading {
                ModelLoadingLabel(isLoading: self.keyboardState.isModelLoading)
                  .transition(.opacity)
              } else if self.keyboardState.isLowDiskSpace {
                self.lowDiskSpaceWarning
                  .transition(.opacity)
              }
            }
            .animation(.easeOut(duration: 0.3), value: self.keyboardState.isModelLoading)
            .animation(.easeOut(duration: 0.3), value: self.keyboardState.isLowDiskSpace)
          }
        VStack(spacing: 8.5) {
          self.micRow
          self.bottomRow
        }
      }
      .padding(.top, 14.5)
      .overlay(alignment: .top) {
        if self.keyboardState.showLLMActions {
          LLMActionBar(
            onSelectAction: { action, customId in
              self.keyboardState.showLLMActions = false
              self.proxy.requestLLMProcessing(action, customId)
            },
            keyboardState: self.keyboardState,
          )
          .padding(.top, 8)
          .transition(.identity)
        }
      }
      .onChange(of: self.keyboardState.showLLMActions) { _, visible in
        self.proxy.setActionBarVisible(visible)
      }
      .onChange(of: self.keyboardState.isRecording) { oldValue, isRecording in
        if isRecording { self.keyboardState.showLLMActions = false }
        if isRecording, !oldValue, !self.isMorphing {
          self.morphDirection = .toWave
          self.isMorphing = true
        } else if
          !isRecording, oldValue, !self.isMorphing, !self.showSpinner, !self.isSpinnerMorphing,
          !self.pendingSpinnerMorph
        {
          self.morphDirection = .toMic
          self.isMorphing = true
        }
      }
      .onChange(of: self.keyboardState.isLLMProcessing) { _, isProcessing in
        if isProcessing { self.keyboardState.showLLMActions = false }
      }
      .task(id: self.keyboardState.isProcessing) {
        let isProcessing = self.keyboardState.isProcessing
        if isProcessing {
          do {
            try await Task.sleep(for: Self.spinnerDelay)
          } catch {
            return
          }
          self.showSpinner = true
        } else {
          if self.showSpinner {
            self.pendingSpinnerMorph = true
          }
          self.showSpinner = false
        }
      }
      .onAppear {
        self.keyboardState.openURLAction = { [openURL] url in
          openURL(url)
        }
      }
    }
  }

  // MARK: Private

  private static let wideButtonWidth: CGFloat = 92
  private static let buttonSpacing: CGFloat = 6

  private static let spinnerDelay = Duration.milliseconds(600)

  @State private var showSpinner = false
  @State private var isMorphing = false
  @State private var isSpinnerMorphing = false
  @State private var spinnerMorphCanStep = false
  @State private var pendingSpinnerMorph = false
  @State private var morphDirection = MicMorphAnimation.Direction.toWave

  @Environment(\.openURL) private var openURL

  private var lowDiskSpaceWarning: some View {
    HStack(spacing: 4) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
      Text("Low storage causes constant model rebuilds")
    }
    .font(.subheadline.weight(.semibold))
  }

  private var activeBlocker: SetupBlocker? {
    if !self.keyboardState.hasFullAccess {
      .fullAccessMissing
    } else if !self.keyboardState.isMicrophoneAuthorized {
      .micDenied
    } else if !self.keyboardState.hasUsableModel {
      .noModel
    } else {
      nil
    }
  }

  @ViewBuilder
  private var micButtonLabel: some View {
    let shouldShowWave = self.keyboardState.isRecording
    let isLoading = self.keyboardState.isModelLoading && !self.keyboardState.isRecording
    let isSpin = self.showSpinner || (isLoading && !self.isSpinnerMorphing && !self.pendingSpinnerMorph)
    let isIdle = !shouldShowWave && !isSpin && !self.isMorphing && !self.isSpinnerMorphing
      && !self.pendingSpinnerMorph
    ZStack {
      MicMorphShape(frameIndex: 0)
        .fill(.primary)
        .frame(width: 56, height: 42)
        .opacity(isIdle ? 1 : 0)
        .transaction { $0.animation = nil }

      if self.isMorphing {
        MicMorphAnimation(direction: self.morphDirection, onComplete: self.handleMicMorphComplete)
          .frame(width: 56, height: 42)
          .transition(.identity)
      }

      if self.isSpinnerMorphing {
        SpinnerMorphAnimation(canStep: self.spinnerMorphCanStep) {
          self.isSpinnerMorphing = false
          self.spinnerMorphCanStep = false
        }
        .frame(width: 56, height: 42)
        .transition(.identity)
      }

      WaveformBars(level: self.keyboardState.audioLevel)
        .opacity(
          shouldShowWave && !isSpin && !self.isMorphing
            && !self.isSpinnerMorphing && !self.pendingSpinnerMorph ? 1 : 0
        )

      self.spinnerView(isSpin: isSpin)
    }
  }

  private var micButton: some View {
    Button {
      if self.keyboardState.isRecording {
        self.proxy.stopDictation()
      } else if self.keyboardState.isSessionActive {
        self.proxy.startDictation()
      } else if let url = DeepLink.dictateURL {
        let settings = SharedSettings()
        settings.keyboardRequestedDictation = true
        settings.dictationSessionToken = UUID().uuidString
        settings.synchronize()
        self.openURL(url)
      }
    } label: {
      self.micButtonLabel
    }
    .buttonStyle(CircleKeyStyle())
    .allowsHitTesting(!self.keyboardState.isProcessing)
  }

  private var showAIButton: Bool {
    self.keyboardState.llmEnabled && self.keyboardState.hasUsableLLMModel
  }

  private var sideButtonWidth: CGFloat {
    (self.keyboardState.selectedVariantSupportsTranslation || self.showAIButton) ? 43 : 45
  }

  private var returnButtonWidth: CGFloat {
    self.keyboardState.needsInputModeSwitchKey
      ? self.sideButtonWidth + Self.buttonSpacing + Self.wideButtonWidth
      : Self.wideButtonWidth
  }

  private var micRow: some View {
    ZStack(alignment: .bottom) {
      self.sideButtons
      self.micButtonWithPulse
    }
    .padding(.horizontal, 4)
  }

  private var showPulseRings: Bool {
    self.keyboardState.isRecording && !self.keyboardState.isProcessing
  }

  private var micButtonWithPulse: some View {
    ZStack {
      PulseRings()
        .opacity(self.showPulseRings ? 1 : 0)
        .scaleEffect(self.showPulseRings ? 1 : 0.69)
        .animation(.easeOut(duration: 0.4), value: self.showPulseRings)

      self.micButton
    }
    .frame(minHeight: PulseRings.maxDiameter)
    .padding(.bottom, 6)
  }

}

// MARK: - KeyboardView Helpers

extension KeyboardView {
  private var sideButtons: some View {
    HStack(alignment: .bottom, spacing: Self.buttonSpacing) {
      KeyButton(systemImage: "gearshape", fixedWidth: self.sideButtonWidth) {
        if let url = DeepLink.settingsURL { self.proxy.openURL(url) }
      }
      if self.keyboardState.selectedVariantSupportsTranslation {
        TranslateToggleButton(fixedWidth: self.sideButtonWidth, keyboardState: self.keyboardState)
          .transition(.opacity.combined(with: .scale))
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8.5) {
        if self.keyboardState.hasLLMHistory {
          self.undoRedoRow
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        HStack(spacing: Self.buttonSpacing) {
          if self.showAIButton {
            self.aiButton.transition(.opacity.combined(with: .scale))
          }
          KeyButton(systemImage: "delete.left", fixedWidth: self.sideButtonWidth) {
            self.proxy.deleteBackward()
          }
        }
      }
    }
    .animation(.easeInOut(duration: 0.35), value: self.keyboardState.selectedVariantSupportsTranslation)
    .animation(.easeInOut(duration: 0.35), value: self.showAIButton)
    .animation(.easeInOut(duration: 0.25), value: self.keyboardState.hasLLMHistory)
  }

  private var undoRedoRow: some View {
    HStack(spacing: Self.buttonSpacing) {
      KeyButton(systemImage: "arrow.uturn.backward", fixedWidth: self.sideButtonWidth) {
        self.proxy.undoLLM()
      }
      .disabled(!self.keyboardState.canUndoLLM)
      .opacity(self.keyboardState.canUndoLLM ? 1 : 0.35)

      KeyButton(systemImage: "arrow.uturn.forward", fixedWidth: self.sideButtonWidth) {
        self.proxy.redoLLM()
      }
      .disabled(!self.keyboardState.canRedoLLM)
      .opacity(self.keyboardState.canRedoLLM ? 1 : 0.35)
    }
  }

  @ViewBuilder
  private var aiButton: some View {
    if self.keyboardState.isLLMProcessing {
      MetaballSpinner(color: .primary, size: 18)
        .frame(width: self.sideButtonWidth, height: 45)
        .background {
          RoundedRectangle(cornerRadius: 8.5, style: .continuous)
            .fill(Color(.keyBackground))
        }
    } else {
      let isRecording = self.keyboardState.isRecording
      AIButton(
        fixedWidth: self.sideButtonWidth,
        onTap: { withAnimation { self.keyboardState.showLLMActions.toggle() } },
        onLongPress: { self.executeLongPressAction() },
        longPressEnabled: self.keyboardState.longPressLLMAction.isSet,
        isActive: self.keyboardState.showLLMActions,
      )
      .opacity(isRecording ? 0.5 : 1)
      .allowsHitTesting(!isRecording)
      .animation(.easeOut(duration: 0.2), value: isRecording)
    }
  }

  private var bottomRow: some View {
    HStack(spacing: Self.buttonSpacing) {
      if self.keyboardState.needsInputModeSwitchKey {
        GlobeKey(fixedWidth: self.sideButtonWidth)
      }

      KeyButton(systemImage: "trash", fixedWidth: Self.wideButtonWidth) {
        self.proxy.deleteAll()
      }

      SpaceBarKey(
        useCustomSpaceBar: self.keyboardState.useCustomSpaceBar,
        onSpace: { self.proxy.insertText(" ") },
        onCursorMove: { self.proxy.adjustTextPosition($0) },
      )

      KeyButton(systemImage: "return.left", fixedWidth: self.returnButtonWidth) {
        self.proxy.insertText("\n")
      }
    }
    .padding(.horizontal, 4)
    .padding(.bottom, 4)
  }

  private func spinnerView(isSpin: Bool) -> some View {
    MetaballSpinner(color: .primary, size: 42)
      .scaleEffect(isSpin ? 1 : 0.01)
      .transaction(value: isSpin) { transaction in
        transaction.animation = .easeOut(duration: 0.2)
        if !isSpin {
          transaction.addAnimationCompletion {
            if self.pendingSpinnerMorph {
              self.pendingSpinnerMorph = false
              self.isSpinnerMorphing = true
              self.spinnerMorphCanStep = true
            }
          }
        }
      }
  }

  private func handleMicMorphComplete() {
    let wantWave = self.keyboardState.isRecording
    self.isMorphing = false
    if self.morphDirection == .toWave, !wantWave {
      self.morphDirection = .toMic
      self.isMorphing = true
    } else if self.morphDirection == .toMic, wantWave {
      self.morphDirection = .toWave
      self.isMorphing = true
    }
  }

  private func executeLongPressAction() {
    let resolved = self.keyboardState.longPressLLMAction.resolve(
      defaultAction: .rewrite,
      customPrompts: self.keyboardState.llmCustomPrompts,
      disabledActions: self.keyboardState.disabledLLMActions,
    )
    if let resolved {
      self.proxy.requestLLMProcessing(resolved.action, resolved.customPromptId)
    } else {
      self.keyboardState.showLLMActions = true
    }
  }
}
