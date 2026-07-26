import SwiftUI
import UIKit

// MARK: - Keyboard Colors

extension UIColor {
  /// Letter-key background. Light: #FFFFFF, Dark: #3A3A3C (systemGray4).
  static let keyBackground = UIColor { traits in
    traits.userInterfaceStyle == .dark ? .systemGray4 : .white
  }

  /// Pressed-state fill. Light: #D1D1D6 (systemGray4), Dark: #636366 (systemGray2).
  /// Apple-faithful inversion: dark press jumps toward letter-key tone for stronger feedback.
  static let keyPressedBackground = UIColor { traits in
    traits.userInterfaceStyle == .dark ? .systemGray2 : .systemGray4
  }
}

// MARK: - Key Press Transition

extension View {
  /// Single source of truth for press-feedback timing on keyboard keys.
  /// Instant on press, 20ms ease-out on release. Applied to background swap; scope per-style.
  func keyPressTransition(isPressed: Bool) -> some View {
    self.transaction(value: isPressed) { transaction in
      transaction.animation = isPressed ? nil : .easeOut(duration: 0.02)
    }
  }
}

// MARK: - KeyShape

enum KeyShape {
  case pill
  case rounded
}

extension View {
  /// Key chrome background with the standard press-feedback transition.
  @MainActor
  func keyBackground(shape: KeyShape, fill: Color, isPressed: Bool) -> some View {
    self.background {
      Group {
        switch shape {
        case .pill:
          Capsule(style: .continuous).fill(fill)
        case .rounded:
          RoundedRectangle(cornerRadius: KeyboardChromeMetrics.keyCornerRadius, style: .continuous).fill(fill)
        }
      }
      .keyPressTransition(isPressed: isPressed)
    }
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
  let setStatusStripHeight: (CGFloat) -> Void
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
  var shape = KeyShape.rounded
  var pressEffect = true
  var fillOnPress = false
  var pressedBinding: Binding<Bool>?

  func makeBody(configuration: Configuration) -> some View {
    let showPressed = configuration.isPressed && self.pressEffect
    let fill = Color(showPressed ? .keyPressedBackground : .keyBackground)
    return configuration.label
      .symbolVariant(self.fillOnPress && configuration.isPressed ? .fill : .none)
      .contentTransition(.identity)
      .transaction(value: configuration.isPressed) { $0.animation = nil }
      .foregroundStyle(.primary)
      .frame(maxWidth: self.fixedWidth ?? .infinity)
      .frame(width: self.fixedWidth, height: KeyboardChromeMetrics.keyHeight)
      .keyBackground(shape: self.shape, fill: fill, isPressed: showPressed)
      .onChange(of: configuration.isPressed) { _, new in
        self.pressedBinding?.wrappedValue = new
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
        .onAppear { self.proxy.setStatusStripHeight(0) }
    } else if let error = self.keyboardState.llmError {
      LLMErrorPrompt(error: error, keyboardState: self.keyboardState)
        .onAppear { self.proxy.setStatusStripHeight(0) }
    } else {
      Group {
        switch self.keyboardState.keyboardKind {
        case .standard:
          StandardKeyboardLayout(proxy: self.proxy, keyboardState: self.keyboardState)
        case .extended:
          ExtendedKeyboardLayout(proxy: self.proxy, keyboardState: self.keyboardState)
        }
      }
      .padding(.top, 14.5.kbScaled)
      .overlay(alignment: .top) {
        if self.keyboardState.showLLMActions {
          LLMActionBar(
            onSelectAction: { action, customId in
              self.keyboardState.showLLMActions = false
              self.proxy.requestLLMProcessing(action, customId)
            },
            keyboardState: self.keyboardState,
          )
          .padding(.top, 8.kbScaled)
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
      .onAppear {
        self.keyboardState.openURLAction = { [openURL] url in
          openURL(url)
        }
      }
      .environment(\.keyboardHapticsEnabled, self.keyboardState.keyboardHapticsEnabled)
    }
  }

  // MARK: Private

  @Environment(\.openURL) private var openURL

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
}
