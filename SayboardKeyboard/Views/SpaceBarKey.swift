import SwiftUI

// SpaceBarKey -- Space bar with trackpad-style cursor movement on long press + drag

struct SpaceBarKey: View {

  // MARK: Internal

  let useCustomSpaceBar: Bool
  let onSpace: () -> Void
  let onCursorMove: (Int) -> Void

  var body: some View {
    self.label
      .foregroundStyle(.primary)
      .frame(maxWidth: .infinity)
      .frame(height: 45)
      .background {
        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
          .fill(Color(self.isPressed ? .keyPressedBackground : .keyBackground))
      }
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            self.handleDragChanged(value)
          }
          .onEnded { _ in
            self.handleDragEnded()
          }
      )
      .sensoryFeedback(.impact(weight: .light), trigger: self.trackpadActivationCount)
  }

  // MARK: Private

  private static let activationDelay: TimeInterval = 0.3
  private static let pointsPerCharacter: CGFloat = 8
  private static let verticalDeadZone: CGFloat = 50
  private static let minimumHorizontalMovement: CGFloat = 2

  @State private var isPressed = false
  @State private var isTrackpadActive = false
  @State private var pressStartTime: Date?
  @State private var accumulatedOffset: CGFloat = 0
  @State private var lastReportedCharOffset = 0
  @State private var trackpadActivationCount = 0

  @ViewBuilder
  private var label: some View {
    if self.useCustomSpaceBar {
      SayboardWordmark()
        .fill(.primary)
        .opacity(self.isTrackpadActive ? 0.05 : 0.2)
        .frame(height: 21.36)
    } else {
      Image(systemName: "space")
        .font(.system(size: 22))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 10)
    }
  }

  private func handleDragChanged(_ value: DragGesture.Value) {
    if self.pressStartTime == nil {
      self.pressStartTime = value.time
      self.isPressed = true
    }

    guard let startTime = self.pressStartTime else { return }
    let elapsed = value.time.timeIntervalSince(startTime)

    if self.isTrackpadActive {
      // Vertical dead zone: stop cursor movement if finger drifts too far vertically
      guard abs(value.translation.height) < Self.verticalDeadZone else { return }

      let totalOffset = value.translation.width / Self.pointsPerCharacter
      let charOffset = Int(totalOffset)
      let delta = charOffset - self.lastReportedCharOffset

      if delta != 0 {
        self.onCursorMove(delta)
        self.lastReportedCharOffset = charOffset
      }
    } else if
      elapsed >= Self.activationDelay,
      abs(value.translation.width) > Self.minimumHorizontalMovement
    {
      self.isTrackpadActive = true
      self.lastReportedCharOffset = 0
      self.trackpadActivationCount += 1
    }
  }

  private func handleDragEnded() {
    if !self.isTrackpadActive {
      self.onSpace()
    }

    self.isPressed = false
    self.isTrackpadActive = false
    self.pressStartTime = nil
    self.accumulatedOffset = 0
    self.lastReportedCharOffset = 0
  }
}
