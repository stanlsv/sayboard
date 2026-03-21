// MicrophoneTutorialView -- Animated mock of iOS Settings guiding the user to enable Microphone access.

import SwiftUI

// MARK: - MicrophoneTutorialView

struct MicrophoneTutorialView: View {

  // MARK: Internal

  var body: some View {
    VStack(spacing: 0) {
      self.microphoneRow
    }
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 32)
    .coordinateSpace(name: Self.coordinateSpace)
    .onPreferenceChange(CenterPreferenceKey.self) { centers in
      self.rowCenters = centers
    }
    .overlay {
      self.cursorCircle
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task {
      await self.runAnimationLoop()
    }
  }

  // MARK: Private

  private static let coordinateSpace = "micTutorial"
  private static let rowID = "microphone"

  private static let initialDelay: UInt64 = 800_000_000
  private static let cursorTravelDuration = 0.4
  private static let prePressPause: UInt64 = 200_000_000
  private static let pressDuration: UInt64 = 150_000_000
  private static let holdDelay: UInt64 = 1_500_000_000
  private static let resetDelay: UInt64 = 400_000_000

  private static let cursorSize: CGFloat = 36
  private static let cursorPressedScale: CGFloat = 0.75

  @State private var microphoneOn = false
  @State private var cursorPosition = CGPoint.zero
  @State private var cursorVisible = false
  @State private var cursorPressed = false
  @State private var rowCenters = [String: CGPoint]()

  private var microphoneRow: some View {
    HStack {
      Text("Microphone")
        .foregroundStyle(.primary)

      Spacer()

      Toggle(isOn: .constant(self.microphoneOn)) {
        EmptyView()
      }
      .labelsHidden()
      .background(
        GeometryReader { geo in
          Color.clear.preference(
            key: CenterPreferenceKey.self,
            value: [Self.rowID: CGPoint(
              x: geo.frame(in: .named(Self.coordinateSpace)).midX,
              y: geo.frame(in: .named(Self.coordinateSpace)).midY,
            )],
          )
        }
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }

  private var cursorCircle: some View {
    Circle()
      .fill(Color.primary.opacity(self.cursorPressed ? 0.45 : 0.25))
      .frame(width: Self.cursorSize, height: Self.cursorSize)
      .scaleEffect(self.cursorPressed ? Self.cursorPressedScale : 1.0)
      .shadow(color: .primary.opacity(0.1), radius: 4)
      .position(self.cursorPosition)
      .opacity(self.cursorVisible ? 1 : 0)
      .animation(.easeOut(duration: 0.08), value: self.cursorPressed)
  }

  private func runAnimationLoop() async {
    while !Task.isCancelled {
      try? await Task.sleep(nanoseconds: Self.initialDelay)

      // Show cursor, move to toggle
      self.cursorVisible = true
      if let target = self.rowCenters[Self.rowID] {
        withAnimation(.easeInOut(duration: Self.cursorTravelDuration)) {
          self.cursorPosition = target
        }
        try? await Task.sleep(nanoseconds: UInt64(Self.cursorTravelDuration * 1_000_000_000))
      }

      // Press and flip
      try? await Task.sleep(nanoseconds: Self.prePressPause)
      self.cursorPressed = true
      try? await Task.sleep(nanoseconds: Self.pressDuration)
      self.cursorPressed = false
      withAnimation(.easeInOut(duration: 0.25)) {
        self.microphoneOn = true
      }

      // Hold
      try? await Task.sleep(nanoseconds: Self.holdDelay)

      // Fade out cursor, reset
      withAnimation(.easeIn(duration: 0.2)) {
        self.cursorVisible = false
      }
      try? await Task.sleep(nanoseconds: Self.resetDelay)

      withAnimation(.easeIn(duration: 0.2)) {
        self.microphoneOn = false
      }
      try? await Task.sleep(nanoseconds: Self.resetDelay)
    }
  }
}

// MARK: - CenterPreferenceKey

private struct CenterPreferenceKey: PreferenceKey {
  static let defaultValue = [String: CGPoint]()

  static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) {
    value.merge(nextValue()) { _, new in new }
  }
}
