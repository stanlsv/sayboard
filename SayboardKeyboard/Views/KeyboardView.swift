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

private enum SetupBlocker {
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
      self.blockerPrompt(for: blocker)
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
      .onChange(of: self.keyboardState.isRecording) { _, isRecording in
        if isRecording { self.keyboardState.showLLMActions = false }
      }
      .onChange(of: self.keyboardState.isLLMProcessing) { _, isProcessing in
        if isProcessing { self.keyboardState.showLLMActions = false }
      }
      .task(id: self.keyboardState.isProcessing) {
        if self.keyboardState.isProcessing {
          try? await Task.sleep(for: Self.spinnerDelay)
          guard !Task.isCancelled else { return }
          self.showSpinner = true
        } else {
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

  private static let promptIconSize: CGFloat = 40
  private static let promptHorizontalPadding: CGFloat = 32
  private static let capsuleHeight: CGFloat = 40
  private static let spinnerDelay = Duration.milliseconds(600)
  private static let idleWaveLevel: Float = 0.03

  @State private var showSpinner = false

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
    let inDelayWindow = self.keyboardState.isProcessing && !self.showSpinner
    let isWave = self.keyboardState.isRecording || inDelayWindow
    let isLoading = self.keyboardState.isModelLoading && !self.keyboardState.isRecording
    let isSpin = self.showSpinner || isLoading
    let isIdle = !isWave && !isSpin
    let effectiveLevel = inDelayWindow ? Self.idleWaveLevel : self.keyboardState.audioLevel

    ZStack {
      Image(systemName: "mic.fill")
        .font(.system(size: 42))
        .opacity(isIdle ? 1 : 0)
        .scaleEffect(isIdle ? 1 : 0.8)
        .animation(.easeOut(duration: 0.1), value: isIdle)

      WaveformBars(level: effectiveLevel)
        .opacity(isWave && !isSpin ? 1 : 0)
        .scaleEffect(isWave && !isSpin ? 1 : 0.01)

      MetaballSpinner(color: .primary, size: 42)
        .opacity(isSpin ? 1 : 0)
        .scaleEffect(isSpin ? 1 : 0.01)
    }
  }

  @ViewBuilder
  private var micButton: some View {
    if self.keyboardState.isProcessing {
      self.micButtonLabel
        .frame(width: 106, height: 106)
        .background {
          Circle()
            .fill(Color(.keyBackground))
        }
    } else if self.keyboardState.isRecording {
      Button {
        self.proxy.stopDictation()
      } label: {
        self.micButtonLabel
      }
      .buttonStyle(CircleKeyStyle())
    } else if self.keyboardState.isSessionActive {
      Button {
        self.proxy.startDictation()
      } label: {
        self.micButtonLabel
      }
      .buttonStyle(CircleKeyStyle())
    } else if let url = DeepLink.dictateURL {
      Button {
        let settings = SharedSettings()
        settings.keyboardRequestedDictation = true
        settings.dictationSessionToken = UUID().uuidString
        settings.synchronize()
        self.openURL(url)
      } label: {
        self.micButtonLabel
          .frame(width: 106, height: 106)
          .background { Circle().fill(Color(.keyBackground)) }
      }
      .tint(.primary)
    }
  }

  private var showAIButton: Bool {
    self.keyboardState.llmEnabled && self.keyboardState.hasUsableLLMModel
  }

  private var sideButtonWidth: CGFloat {
    (self.keyboardState.selectedVariantSupportsTranslation || self.showAIButton) ? 43 : 45
  }

  private var micRow: some View {
    ZStack(alignment: .bottom) {
      self.sideButtons
      self.micButtonWithPulse
    }
    .padding(.horizontal, 4)
  }

  private var sideButtons: some View {
    HStack(alignment: .bottom, spacing: 6) {
      KeyButton(systemImage: "gearshape", fixedWidth: self.sideButtonWidth) {
        if let url = DeepLink.settingsURL { self.proxy.openURL(url) }
      }
      if self.keyboardState.selectedVariantSupportsTranslation {
        TranslateToggleButton(keyboardState: self.keyboardState)
          .transition(.opacity.combined(with: .scale))
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8.5) {
        if self.keyboardState.hasLLMHistory {
          self.undoRedoRow
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        HStack(spacing: 6) {
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
    HStack(spacing: 6) {
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

  private var micButtonWithPulse: some View {
    ZStack {
      if self.keyboardState.isRecording, !self.keyboardState.isProcessing {
        PulseRings()
          .transition(.scale(scale: 0.69))
          .animation(.easeOut(duration: 0.4), value: self.keyboardState.isRecording)
      }
      self.micButton
    }
    .animation(.easeOut(duration: 0.2), value: self.keyboardState.isRecording)
    .animation(.easeOut(duration: 0.2), value: self.keyboardState.isProcessing)
    .animation(.easeOut(duration: 0.2), value: self.showSpinner)
    .frame(minHeight: PulseRings.maxDiameter)
    .padding(.bottom, 6)
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
    HStack(spacing: 6) {
      KeyButton(systemImage: "trash", fixedWidth: 92) {
        self.proxy.deleteAll()
      }

      SpaceBarKey(
        useCustomSpaceBar: self.keyboardState.useCustomSpaceBar,
        onSpace: { self.proxy.insertText(" ") },
        onCursorMove: { self.proxy.adjustTextPosition($0) },
      )

      KeyButton(systemImage: "return.left", fixedWidth: 92) {
        self.proxy.insertText("\n")
      }
    }
    .padding(.horizontal, 4)
    .padding(.bottom, 4)
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

  private func blockerPrompt(for blocker: SetupBlocker) -> some View {
    VStack(spacing: 12) {
      Image(systemName: blocker.icon)
        .font(.system(size: Self.promptIconSize))
        .foregroundStyle(.blue)

      Text(blocker.message)
        .font(.subheadline.weight(.semibold))
        .multilineTextAlignment(.center)
        .padding(.horizontal, Self.promptHorizontalPadding)

      if let url = blocker.linkURL {
        Link(destination: url) {
          Text(blocker.buttonTitle)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(minHeight: Self.capsuleHeight)
            .background(.blue, in: Capsule())
        }
        .padding(.horizontal, Self.promptHorizontalPadding)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

}
