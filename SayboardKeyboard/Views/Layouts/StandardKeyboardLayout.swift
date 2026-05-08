import SwiftUI

// MARK: - StandardKeyboardLayout

struct StandardKeyboardLayout: View {

  // MARK: Internal

  let proxy: KeyboardProxy

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    VStack(spacing: 0) {
      Color.clear
        .overlay {
          Group {
            let showModelLoading = self.keyboardState.isModelLoading && self.keyboardState.isProcessing
            if showModelLoading {
              ModelLoadingLabel(isLoading: self.keyboardState.isModelLoading)
                .transition(.opacity)
            } else if self.keyboardState.isLowDiskSpace {
              KeyboardLowDiskSpaceWarning()
                .transition(.opacity)
            }
          }
          .animation(.easeOut(duration: 0.3), value: self.keyboardState.isModelLoading)
          .animation(.easeOut(duration: 0.3), value: self.keyboardState.isLowDiskSpace)
        }
      VStack(spacing: 8.5.kbScaled) {
        self.micRow
        KeyboardBottomRow(proxy: self.proxy, metrics: self.chrome, keyboardState: self.keyboardState)
      }
    }
  }

  // MARK: Private

  private var chrome: KeyboardChromeMetrics {
    KeyboardChromeMetrics(keyboardState: self.keyboardState)
  }

  private var micRow: some View {
    ZStack(alignment: .bottom) {
      self.sideButtons
      MicButtonWithPulse(sizing: .standard, proxy: self.proxy, keyboardState: self.keyboardState)
        .padding(.bottom, 6.kbScaled)
    }
    .padding(.horizontal, 4.kbScaled)
  }

}

// MARK: - StandardKeyboardLayout Helpers

extension StandardKeyboardLayout {
  private var sideButtons: some View {
    HStack(alignment: .bottom, spacing: KeyboardChromeMetrics.buttonSpacing) {
      KeyButton(
        content: .systemImage("gearshape"),
        fixedWidth: self.chrome.sideButtonWidth,
        fillOnPress: true,
      ) {
        if let url = DeepLink.settingsURL { self.proxy.openURL(url) }
      }
      if self.keyboardState.selectedVariantSupportsTranslation {
        TranslateToggleButton(fixedWidth: self.chrome.sideButtonWidth, keyboardState: self.keyboardState)
          .transition(.opacity.combined(with: .scale))
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 8.5.kbScaled) {
        if self.keyboardState.hasLLMHistory {
          self.undoRedoRow
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        HStack(spacing: KeyboardChromeMetrics.buttonSpacing) {
          if self.keyboardState.showsAIButton {
            self.aiButton.transition(.opacity.combined(with: .scale))
          }
          KeyButton(
            content: .systemImage("delete.left"),
            fixedWidth: self.chrome.sideButtonWidth,
            fillOnPress: true,
          ) {
            self.proxy.deleteBackward()
          }
        }
      }
    }
    .animation(.easeInOut(duration: 0.35), value: self.keyboardState.selectedVariantSupportsTranslation)
    .animation(.easeInOut(duration: 0.35), value: self.keyboardState.showsAIButton)
    .animation(.easeInOut(duration: 0.25), value: self.keyboardState.hasLLMHistory)
  }

  private var undoRedoRow: some View {
    HStack(spacing: KeyboardChromeMetrics.buttonSpacing) {
      KeyButton(content: .systemImage("arrow.uturn.backward"), fixedWidth: self.chrome.sideButtonWidth) {
        self.proxy.undoLLM()
      }
      .disabled(!self.keyboardState.canUndoLLM)
      .opacity(self.keyboardState.canUndoLLM ? 1 : 0.35)

      KeyButton(content: .systemImage("arrow.uturn.forward"), fixedWidth: self.chrome.sideButtonWidth) {
        self.proxy.redoLLM()
      }
      .disabled(!self.keyboardState.canRedoLLM)
      .opacity(self.keyboardState.canRedoLLM ? 1 : 0.35)
    }
  }

  @ViewBuilder
  private var aiButton: some View {
    if self.keyboardState.isLLMProcessing {
      MetaballSpinner(color: .primary, size: 18.kbScaled)
        .frame(width: self.chrome.sideButtonWidth, height: 45.kbScaled)
        .background {
          RoundedRectangle(cornerRadius: 8.5.kbScaled, style: .continuous)
            .fill(Color(.keyBackground))
        }
    } else {
      let isRecording = self.keyboardState.isRecording
      AIButton(
        fixedWidth: self.chrome.sideButtonWidth,
        onTap: { withAnimation { self.keyboardState.showLLMActions.toggle() } },
        onLongPress: { KeyboardActions.longPressLLM(state: self.keyboardState, proxy: self.proxy) },
        longPressEnabled: self.keyboardState.longPressLLMAction.isSet,
        isActive: self.keyboardState.showLLMActions,
      )
      .opacity(isRecording ? 0.5 : 1)
      .allowsHitTesting(!isRecording)
      .animation(.easeOut(duration: 0.2), value: isRecording)
    }
  }
}
