import SwiftUI

// ModelLoadingLabel -- Honest "preparing speech model" status with animated dots.
//
// Shown while an installed speech model is being (re-)prepared for the Neural Engine.
// After iOS purges the Core ML compiled cache under storage pressure, the next load
// re-specializes the model (the slow "rebuild"); `lowStorage` flags that case so the
// user understands why the wait is happening.
//
// `isFirstUse` marks the genuine first build (no model prepared yet) so the copy can say
// this setup is one-time; gated by SharedSettings.hasPreparedModelOnce, never on rebuilds.

struct ModelLoadingLabel: View {

  // MARK: Internal

  var isLoading: Bool
  var lowStorage: Bool
  var isFirstUse: Bool

  var body: some View {
    self.labelText
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .font(.subheadline.weight(.semibold))
      .padding(.horizontal, 12.kbScaled)
      .padding(.top, 4.kbScaled)
      .padding(.bottom, 8.kbScaled)
      .task(id: self.isLoading) {
        guard self.isLoading else { return }
        self.dotCount = 1
        await self.runDotTimer()
      }
  }

  // MARK: Private

  private static let maxDots = 3
  private static let dotInterval = Duration.seconds(1)

  @State private var dotCount = 1

  /// Message with an animated trailing ellipsis, plus a leading warning emoji in
  /// the low-storage case so the marker sits inline at the start of the first
  /// line. The unused dots are kept as a clear (invisible) run so the total width
  /// stays constant — the text never reflows and the measured keyboard height
  /// never jitters as the dots animate. One concatenated `Text` so the emoji
  /// leads and the dots trail even when the message wraps to multiple lines.
  private var labelText: Text {
    let dots = Text(verbatim: String(repeating: ".", count: self.dotCount))
      + Text(verbatim: String(repeating: ".", count: Self.maxDots - self.dotCount)).foregroundColor(.clear)
    let text = Text(self.message) + dots
    guard self.lowStorage else { return text }
    return Text(verbatim: "\u{26A0}\u{FE0F} ") + text
  }

  private var message: LocalizedStringKey {
    if self.lowStorage {
      "Storage critically low. Free up space so the model doesn't keep rebuilding. Rebuilding it now"
    } else if self.isFirstUse {
      "Preparing speech model for first use"
    } else {
      "Preparing speech model"
    }
  }

  private func runDotTimer() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: Self.dotInterval)
      guard !Task.isCancelled else { return }
      self.dotCount = self.dotCount % 3 + 1
    }
  }
}
