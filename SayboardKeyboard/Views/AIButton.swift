// AIButton -- AI action button with tap (action sheet) and long press (direct action + haptic)

import SwiftUI

struct AIButton: View {

  // MARK: Internal

  let fixedWidth: CGFloat
  let onTap: () -> Void
  let onLongPress: () -> Void
  let longPressEnabled: Bool
  var isActive = false

  var body: some View {
    if self.longPressEnabled {
      self.label
        .scaleEffect(self.isPressed ? Self.pressedScale : 1.0)
        .animation(.spring(duration: 0.25, bounce: 0.3), value: self.isPressed)
        .onLongPressGesture(
          minimumDuration: Self.longPressDuration,
          pressing: { pressing in
            self.isPressed = pressing
            if pressing {
              self.longPressFired = false
            }
          },
          perform: {
            self.longPressFired = true
            self.longPressCount += 1
            self.onLongPress()
          },
        )
        .simultaneousGesture(
          TapGesture()
            .onEnded {
              if !self.longPressFired {
                self.onTap()
              }
            }
        )
        .sensoryFeedback(.impact(weight: .medium), trigger: self.longPressCount)
    } else {
      Button(action: self.onTap) {
        self.label
      }
      .buttonStyle(RectKeyStyle(fixedWidth: self.fixedWidth))
    }
  }

  // MARK: Private

  private static let longPressDuration = 0.4
  private static let pressedScale: CGFloat = 1.15

  @State private var isPressed = false
  @State private var longPressFired = false
  @State private var longPressCount = 0

  private var label: some View {
    Image(systemName: self.isActive ? "xmark" : "sparkles")
      .font(.system(size: 18))
      .foregroundStyle(.primary)
      .contentTransition(.symbolEffect(.replace, options: .speed(2)))
      .animation(.easeOut(duration: 0.15), value: self.isActive)
      .frame(width: self.fixedWidth, height: 45)
      .background {
        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
          .fill(Color(self.isPressed ? .keyPressedBackground : .keyBackground))
          .animation(nil, value: self.isPressed)
      }
  }

}
