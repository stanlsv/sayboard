import SwiftUI

// ModelLoadingLabel -- "Initial setup... (XX%)" with animated dots and simulated progress

struct ModelLoadingLabel: View {

  // MARK: Internal

  var isLoading: Bool

  var body: some View {
    HStack(spacing: 0) {
      Text("Initial setup")
      ZStack(alignment: .leading) {
        Text(verbatim: "...").opacity(0) // reserves 3-dot width
        Text(verbatim: String(repeating: ".", count: self.dotCount))
      }
      Text(verbatim: " (\(self.percent)%)")
        .monospacedDigit()
    }
    .font(.subheadline.weight(.semibold))
    .task(id: self.isLoading) {
      guard self.isLoading else {
        self.showCompletion()
        return
      }
      self.elapsed = 0
      self.percent = 0
      self.dotCount = 1
      await self.runTimers()
    }
  }

  // MARK: Private

  private static let tickInterval = Duration.milliseconds(500)
  private static let dotInterval = Duration.seconds(1)

  // Progress curve breakpoints
  private static let phase1End: Double = 15 // 0-50% in 15s
  private static let phase2End: Double = 40 // 50-95% in 25s
  private static let phase1Rate = 50.0 / 15.0 // ~3.3%/s
  private static let phase2Rate = 45.0 / 25.0 // ~1.8%/s
  private static let phase3Rate = 1.0 / 60.0 // 1%/min
  private static let maxPercent = 99

  @State private var dotCount = 1
  @State private var percent = 0
  @State private var elapsed: Double = 0

  private func runTimers() async {
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await self.runProgressTimer() }
      group.addTask { await self.runDotTimer() }
      await group.waitForAll()
    }
  }

  private func runProgressTimer() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: Self.tickInterval)
      guard !Task.isCancelled else { return }
      self.elapsed += 0.5
      self.percent = min(Self.maxPercent, self.computePercent())
    }
  }

  private func runDotTimer() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: Self.dotInterval)
      guard !Task.isCancelled else { return }
      self.dotCount = self.dotCount % 3 + 1
    }
  }

  private func computePercent() -> Int {
    if self.elapsed <= Self.phase1End {
      return Int(self.elapsed * Self.phase1Rate)
    } else if self.elapsed <= Self.phase2End {
      let extra = (self.elapsed - Self.phase1End) * Self.phase2Rate
      return Int(50 + extra)
    } else {
      let extra = (self.elapsed - Self.phase2End) * Self.phase3Rate
      return Int(95 + extra)
    }
  }

  private func showCompletion() {
    self.percent = 100
    self.dotCount = 3
  }
}
