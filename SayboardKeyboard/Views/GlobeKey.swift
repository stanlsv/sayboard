import SwiftUI

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
