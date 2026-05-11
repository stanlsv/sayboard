import SwiftUI

// MARK: - KeyboardState + Chrome Visibility

extension KeyboardState {
  var showsAIButton: Bool {
    self.llmEnabled && self.hasUsableLLMModel
  }

  var showsGlobeButton: Bool {
    self.needsInputModeSwitchKey || self.showGlobeKey
  }
}

// MARK: - KeyboardChromeMetrics

struct KeyboardChromeMetrics {

  // MARK: Lifecycle

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

  // MARK: Internal

  @MainActor
  static var buttonSpacing: CGFloat {
    6.kbScaled
  }

  let sideButtonWidth: CGFloat
  let trashWidth: CGFloat
  let returnWidth: CGFloat
  let showsGlobe: Bool

}

// MARK: - KeyboardLowDiskSpaceWarning

struct KeyboardLowDiskSpaceWarning: View {
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
      Text("Low storage causes constant model rebuilds")
    }
    .font(.subheadline.weight(.semibold))
  }
}

// MARK: - KeyboardBottomRow

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

// MARK: - KeyboardActions

@MainActor
enum KeyboardActions {
  /// Invokes the configured long-press AI action; falls back to opening the LLM actions menu.
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
