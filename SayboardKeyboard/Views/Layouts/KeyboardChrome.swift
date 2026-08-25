import SwiftUI

extension KeyboardState {
  var showsAIButton: Bool {
    self.llmEnabled && self.hasUsableLLMModel
  }

  var showsGlobeButton: Bool {
    self.needsInputModeSwitchKey || self.showGlobeKey
  }
}

struct KeyboardChromeMetrics {

  @MainActor
  init(keyboardState: KeyboardState) {
    let compact = keyboardState.selectedVariantSupportsTranslation || keyboardState.showsAIButton
    let side: CGFloat = (compact ? 43 : 45).kbScaled
    let wide: CGFloat = 92.kbScaled
    let showsGlobe = keyboardState.showsGlobeButton

    self.sideButtonWidth = side
    self.showsGlobe = showsGlobe
    self.trashWidth = showsGlobe ? side : wide
    self.returnWidth = showsGlobe ? (side + Self.buttonSpacing + side) : wide
  }

  @MainActor
  static var buttonSpacing: CGFloat {
    6.kbScaled
  }

  @MainActor
  static var keyHeight: CGFloat {
    45.kbScaled
  }

  @MainActor
  static var keyCornerRadius: CGFloat {
    8.5.kbScaled
  }

  let sideButtonWidth: CGFloat
  let trashWidth: CGFloat
  let returnWidth: CGFloat
  let showsGlobe: Bool

}

struct KeyboardStatusStrip: View {

  @ObservedObject var keyboardState: KeyboardState

  let onContentHeightChange: (CGFloat) -> Void

  var body: some View {
    Color.clear
      .overlay(alignment: .top) {
        Group {
          if self.showModelLoading {
            ModelLoadingLabel(
              isLoading: self.keyboardState.isModelLoading,
              lowStorage: self.keyboardState.isLowDiskSpace,
              isFirstUse: !self.keyboardState.hasPreparedModelOnce,
            )
            .transition(.opacity)
          } else if let outcome = self.keyboardState.dictationOutcome {
            DictationOutcomeLabel(outcome: outcome) {
              self.keyboardState.dictationOutcome = nil
            }
            .transition(.opacity)
          }
        }
        .animation(.easeOut(duration: 0.3), value: self.keyboardState.isModelLoading)
        .animation(.easeOut(duration: 0.3), value: self.keyboardState.isLowDiskSpace)
        .animation(.easeOut(duration: 0.3), value: self.keyboardState.dictationOutcome)
        .background {
          GeometryReader { geo in
            Color.clear
              .onAppear { self.onContentHeightChange(geo.size.height) }
              .onChange(of: geo.size.height) { _, height in
                self.onContentHeightChange(height)
              }
          }
        }
      }
  }

  private var showModelLoading: Bool {
    self.keyboardState.isModelLoading && self.keyboardState.isProcessing
  }
}

struct KeyboardBottomRow: View {

  let proxy: KeyboardProxy
  let metrics: KeyboardChromeMetrics

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    HStack(spacing: KeyboardChromeMetrics.buttonSpacing) {
      if self.metrics.showsGlobe {
        GlobeKey(fixedWidth: self.metrics.sideButtonWidth)
      }

      KeyButton(
        content: .systemImage("trash"),
        fixedWidth: self.metrics.trashWidth,
        fillOnPress: true,
        firesHaptic: false,
      ) {
        self.proxy.deleteAll()
      }

      SpaceBarKey(
        useCustomSpaceBar: self.keyboardState.useCustomSpaceBar,
        onSpace: { self.proxy.insertText(" ") },
        onCursorMove: { self.proxy.adjustTextPosition($0) },
      )

      KeyButton(content: .systemImage("return.left"), fixedWidth: self.metrics.returnWidth) {
        self.proxy.insertText("\n")
      }
    }
    .padding(.horizontal, 4.kbScaled)
    .padding(.bottom, 4.kbScaled)
  }
}

@MainActor
enum KeyboardActions {
  static func longPressLLM(state: KeyboardState, proxy: KeyboardProxy) {
    let resolved = state.longPressLLMAction.resolve(
      defaultAction: .rewrite,
      customPrompts: state.llmCustomPrompts,
      disabledActions: state.disabledLLMActions,
    )
    if let resolved {
      proxy.requestLLMProcessing(resolved.action, resolved.customPromptId)
    } else {
      state.showLLMActions = true
    }
  }
}
