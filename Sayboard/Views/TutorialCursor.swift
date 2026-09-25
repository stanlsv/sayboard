
import SwiftUI

struct TutorialCursor: View {

  let position: CGPoint
  let isVisible: Bool
  let isPressed: Bool
  var size: CGFloat = 36

  var body: some View {
    Circle()
      .fill(Color.primary.opacity(self.isPressed ? Self.pressedOpacity : Self.restingOpacity))
      .frame(width: self.size, height: self.size)
      .scaleEffect(self.isPressed ? Self.pressedScale : 1)
      .shadow(color: .primary.opacity(0.1), radius: 4)
      .position(self.position)
      .opacity(self.isVisible ? 1 : 0)
      .animation(.easeOut(duration: 0.08), value: self.isPressed)
  }

  private static let restingOpacity = 0.25
  private static let pressedOpacity = 0.45
  private static let pressedScale: CGFloat = 0.75
}
