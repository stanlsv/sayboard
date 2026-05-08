import SwiftUI

// MARK: - ExtendedKeyboardLayout

struct ExtendedKeyboardLayout: View {

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
      VStack(spacing: Self.rowSpacing) {
        self.chromeRow
        self.symbolsRow1View
        self.symbolsRow2View
        self.symbolsRow3View
        KeyboardBottomRow(proxy: self.proxy, metrics: self.chrome, keyboardState: self.keyboardState)
      }
    }
  }

  // MARK: Private

  private static let numbersRow1: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
  private static let numbersRow2: [String] = ["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]
  private static let symbolsRow1: [String] = ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]
  private static let symbolsRow2: [String] = ["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]
  private static let punctRow: [String] = [".", ",", "?", "!", "'"]

  @MainActor private static let rowSpacing: CGFloat = 8.5.kbScaled

  @MainActor private static let symbolsRow3WideGap: CGFloat = 12.kbScaled

  private static let symbolsRow3WideKeyWeight: CGFloat = 1.1
  private static let symbolsRow3NarrowKeyWeight: CGFloat = 0.9
  /// Wide keys are the page toggler and delete; narrow keys are `punctRow`.
  private static let symbolsRow3WideKeyCount = 2

  private static var symbolsRow3TotalWeight: CGFloat {
    Self.symbolsRow3WideKeyWeight * CGFloat(Self.symbolsRow3WideKeyCount)
      + Self.symbolsRow3NarrowKeyWeight * CGFloat(Self.punctRow.count)
  }

  @State private var symbolsPage = SymbolsPage.numbers

  private var chrome: KeyboardChromeMetrics {
    KeyboardChromeMetrics(keyboardState: self.keyboardState)
  }

  private var currentRow1: [String] {
    switch self.symbolsPage {
    case .numbers: Self.numbersRow1
    case .symbols: Self.symbolsRow1
    }
  }

  private var currentRow2: [String] {
    switch self.symbolsPage {
    case .numbers: Self.numbersRow2
    case .symbols: Self.symbolsRow2
    }
  }

}

// MARK: - ExtendedKeyboardLayout Helpers

extension ExtendedKeyboardLayout {
  /// Width budget on iPhone SE 2/3 (375pt) with all features enabled is ~359pt,
  /// leaving ~16pt for the Spacer. Verify SE 2 portrait + landscape after edits.
  private var chromeRow: some View {
    HStack(alignment: .center, spacing: KeyboardChromeMetrics.buttonSpacing) {
      KeyButton(
        content: .systemImage("gearshape"),
        fixedWidth: self.chrome.sideButtonWidth,
        shape: .pill,
        fillOnPress: true,
      ) {
        if let url = DeepLink.settingsURL { self.proxy.openURL(url) }
      }
      if self.keyboardState.selectedVariantSupportsTranslation {
        TranslateToggleButton(
          fixedWidth: self.chrome.sideButtonWidth,
          shape: .pill,
          compactStyle: true,
          keyboardState: self.keyboardState,
        )
        .transition(.opacity.combined(with: .scale))
      }
      if self.keyboardState.showsAIButton {
        self.aiButton.transition(.opacity.combined(with: .scale))
      }
      if self.keyboardState.hasLLMHistory {
        self.undoRedoRow
          .transition(.opacity.combined(with: .scale))
      }
      Spacer()
      MicButtonWithPulse(sizing: .extended, proxy: self.proxy, reservesPulseSpace: false, keyboardState: self.keyboardState)
        .padding(12.kbScaled)
    }
    // Leading 12pt mirrors the mic button's own 12pt padding on the right; trailing 4pt
    // is the residual outer gap so the mic compartment hugs the keyboard edge symmetrically.
    .padding(.leading, 12.kbScaled)
    .padding(.trailing, 4.kbScaled)
    .animation(.easeInOut(duration: 0.35), value: self.keyboardState.selectedVariantSupportsTranslation)
    .animation(.easeInOut(duration: 0.35), value: self.keyboardState.showsAIButton)
    .animation(.easeInOut(duration: 0.25), value: self.keyboardState.hasLLMHistory)
  }

  private var undoRedoRow: some View {
    HStack(spacing: KeyboardChromeMetrics.buttonSpacing) {
      KeyButton(content: .systemImage("arrow.uturn.backward"), fixedWidth: self.chrome.sideButtonWidth, shape: .pill) {
        self.proxy.undoLLM()
      }
      .disabled(!self.keyboardState.canUndoLLM)
      .opacity(self.keyboardState.canUndoLLM ? 1 : 0.35)

      KeyButton(content: .systemImage("arrow.uturn.forward"), fixedWidth: self.chrome.sideButtonWidth, shape: .pill) {
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
          Capsule(style: .continuous).fill(Color(.keyBackground))
        }
    } else {
      let isRecording = self.keyboardState.isRecording
      AIButton(
        fixedWidth: self.chrome.sideButtonWidth,
        onTap: { withAnimation { self.keyboardState.showLLMActions.toggle() } },
        onLongPress: { KeyboardActions.longPressLLM(state: self.keyboardState, proxy: self.proxy) },
        longPressEnabled: self.keyboardState.longPressLLMAction.isSet,
        isActive: self.keyboardState.showLLMActions,
        shape: .pill,
      )
      .opacity(isRecording ? 0.5 : 1)
      .allowsHitTesting(!isRecording)
      .animation(.easeOut(duration: 0.2), value: isRecording)
    }
  }

  private var symbolsRow1View: some View {
    HStack(spacing: KeyboardChromeMetrics.buttonSpacing) {
      ForEach(Array(self.currentRow1.enumerated()), id: \.offset) { index, char in
        self.calloutKey(char: char, index: index, count: self.currentRow1.count)
      }
    }
    .padding(.horizontal, 4.kbScaled)
  }

  private var symbolsRow2View: some View {
    HStack(spacing: KeyboardChromeMetrics.buttonSpacing) {
      ForEach(Array(self.currentRow2.enumerated()), id: \.offset) { index, char in
        self.calloutKey(char: char, index: index, count: self.currentRow2.count)
      }
    }
    .padding(.horizontal, 4.kbScaled)
  }

  private var symbolsRow3View: some View {
    GeometryReader { geo in
      let horizontalPadding = 4.kbScaled * 2
      let outerGaps = Self.symbolsRow3WideGap * 2
      let punctInternalGaps = KeyboardChromeMetrics.buttonSpacing * CGFloat(Self.punctRow.count - 1)
      let availableForKeys = geo.size.width - horizontalPadding - outerGaps - punctInternalGaps
      let baseWidth = availableForKeys / Self.symbolsRow3TotalWeight
      self.symbolsRow3Content(
        wideKeyWidth: baseWidth * Self.symbolsRow3WideKeyWeight,
        narrowKeyWidth: baseWidth * Self.symbolsRow3NarrowKeyWeight,
      )
    }
    .frame(height: 45.kbScaled)
  }

  private func symbolsRow3Content(wideKeyWidth: CGFloat, narrowKeyWidth: CGFloat) -> some View {
    HStack(spacing: Self.symbolsRow3WideGap) {
      KeyButton(
        content: .symbol(self.symbolsPage.togglerLabel, fontSize: 18),
        fixedWidth: wideKeyWidth,
        // Avoid a press flash during the animation-suppressed page swap below.
        pressEffect: false,
      ) {
        withTransaction(Transaction(animation: nil)) {
          self.symbolsPage = self.symbolsPage.toggled
        }
      }
      self.punctRowContent(narrowKeyWidth: narrowKeyWidth)
      KeyButton(
        content: .systemImage("delete.left"),
        fixedWidth: wideKeyWidth,
        fillOnPress: true,
      ) {
        self.proxy.deleteBackward()
      }
    }
    .padding(.horizontal, 4.kbScaled)
  }

  private func calloutKey(char: String, index: Int, count: Int) -> some View {
    let alignment: KeyCalloutAlignment =
      if index == 0 {
        .left
      } else if index == count - 1 {
        .right
      } else {
        .center
      }
    return KeyButton(
      content: .symbol(char),
      showsCallout: true,
      calloutRowSpacing: Self.rowSpacing,
      calloutAlignment: alignment,
    ) { self.proxy.insertText(char) }
  }

  private func punctRowContent(narrowKeyWidth: CGFloat) -> some View {
    HStack(spacing: KeyboardChromeMetrics.buttonSpacing) {
      ForEach(Array(Self.punctRow.enumerated()), id: \.offset) { _, char in
        KeyButton(
          content: .symbol(char),
          fixedWidth: narrowKeyWidth,
          showsCallout: true,
          calloutRowSpacing: Self.rowSpacing,
        ) {
          self.proxy.insertText(char)
        }
      }
    }
  }
}
