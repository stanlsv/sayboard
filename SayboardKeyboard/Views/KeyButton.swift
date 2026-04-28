import SwiftUI

struct KeyButton: View {
  var label: LocalizedStringKey?
  var systemImage: String?
  var symbol: String?
  var fixedWidth: CGFloat?
  let action: () -> Void

  var body: some View {
    Button(action: self.action) {
      Group {
        if let systemImage {
          Image(systemName: systemImage)
            .font(.system(size: 18.kbScaled))
        } else if let symbol {
          Text(verbatim: symbol)
            .font(.system(size: 22.kbScaled, weight: .light, design: .monospaced))
        } else if let label {
          Text(label)
            .font(.system(size: 16.kbScaled))
        }
      }
    }
    .buttonStyle(RectKeyStyle(fixedWidth: self.fixedWidth))
  }
}
