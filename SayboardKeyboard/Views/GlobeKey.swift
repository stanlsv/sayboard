import SwiftUI

// GlobeKey -- Globe icon styled to match keyboard keys, with a UIKit overlay
// that handles tap (switch keyboard) and long press (keyboard picker).

struct GlobeKey: View {

  let fixedWidth: CGFloat

  var body: some View {
    Image(systemName: "globe")
      .font(.system(size: 18))
      .foregroundStyle(.primary)
      .frame(width: self.fixedWidth, height: 45)
      .background {
        RoundedRectangle(cornerRadius: 8.5, style: .continuous)
          .fill(Color(.keyBackground))
      }
      .overlay {
        NextKeyboardButton()
      }
  }
}
