import SwiftUI

// GlobeKey -- Globe icon styled to match keyboard keys, with a UIKit overlay
// that handles tap (switch keyboard) and long press (keyboard picker).

struct GlobeKey: View {

  let fixedWidth: CGFloat

  var body: some View {
    Image(systemName: "globe")
      .font(.system(size: 18.kbScaled))
      .foregroundStyle(.primary)
      .frame(width: self.fixedWidth, height: 45.kbScaled)
      .background {
        RoundedRectangle(cornerRadius: 8.5.kbScaled, style: .continuous)
          .fill(Color(.keyBackground))
      }
      .overlay {
        NextKeyboardButton()
      }
  }
}
