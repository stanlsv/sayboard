import SwiftUI
import UIKit

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
