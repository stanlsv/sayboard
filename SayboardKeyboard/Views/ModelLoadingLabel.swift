import SwiftUI

struct ModelLoadingLabel: View {

  var isLoading: Bool
  var lowStorage: Bool
  var isFirstUse: Bool

  var body: some View {
    self.labelText
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12.kbScaled)
      .padding(.top, 4.kbScaled)
      .padding(.bottom, 8.kbScaled)
      .task(id: self.isLoading) {
        guard self.isLoading else { return }
        self.dotCount = 1
        await self.runDotTimer()
      }
  }

  private static let maxDots = 3
  private static let dotInterval = Duration.seconds(1)

  @State private var dotCount = 1

  private var labelText: Text {
    let dots = Text(verbatim: String(repeating: ".", count: self.dotCount))
      + Text(verbatim: String(repeating: ".", count: Self.maxDots - self.dotCount)).foregroundColor(.clear)
    let text = Text(self.message) + dots
    guard self.showsLowStorageWarning else { return text }
    return Text(verbatim: "\u{26A0}\u{FE0F} ") + text
  }

  private var showsLowStorageWarning: Bool {
    self.lowStorage && !OperatingSystem.isBackgroundNeuralEngineBlocked
  }

  private var message: LocalizedStringKey {
    if self.showsLowStorageWarning {
      "Storage critically low. Free up space so the model doesn’t keep rebuilding. Rebuilding it now"
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
