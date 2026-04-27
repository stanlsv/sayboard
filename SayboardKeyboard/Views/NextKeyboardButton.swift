import SwiftUI
import UIKit

// NextKeyboardButton -- Transparent UIButton overlay that sends
// handleInputModeList(from:with:) up the responder chain.
// Tap switches keyboard; long press shows the system keyboard picker.

struct NextKeyboardButton: UIViewRepresentable {

  func makeUIView(context _: Context) -> UIButton {
    let button = UIButton(type: .system)
    button.addTarget(
      nil,
      action: #selector(UIInputViewController.handleInputModeList(from:with:)),
      for: .allTouchEvents,
    )
    button.backgroundColor = .clear
    button.tintColor = .clear
    return button
  }

  func updateUIView(_: UIButton, context _: Context) { }
}
