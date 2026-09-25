
import SwiftUI

struct DictationLockedLabel: View {
  var body: some View {
    Text("Free dictation is used up. Open Sayboard to continue")
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12.kbScaled)
      .padding(.top, 4.kbScaled)
      .padding(.bottom, 8.kbScaled)
  }
}
