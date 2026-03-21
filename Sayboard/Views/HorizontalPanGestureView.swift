import SwiftUI
import UIKit

// HorizontalPanGestureView -- UIKit overlay that recognizes only horizontal pans,
// letting vertical swipes pass through to the parent ScrollView/List.

struct HorizontalPanGestureView: UIViewRepresentable {

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {

    // MARK: Lifecycle

    init(
      onPanBegan: (() -> Void)?,
      onChanged: @escaping (CGFloat) -> Void,
      onEnded: (() -> Void)?,
      onTap: ((CGFloat) -> Void)?,
    ) {
      self.onPanBegan = onPanBegan
      self.onChanged = onChanged
      self.onEnded = onEnded
      self.onTap = onTap
    }

    // MARK: Internal

    var onPanBegan: (() -> Void)?
    var onChanged: (CGFloat) -> Void
    var onEnded: (() -> Void)?
    var onTap: ((CGFloat) -> Void)?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
      guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
      let velocity = pan.velocity(in: pan.view)
      return abs(velocity.x) > abs(velocity.y)
    }

    func gestureRecognizer(
      _: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer,
    ) -> Bool {
      otherGestureRecognizer is UIPanGestureRecognizer
    }

    @objc
    func handlePan(_ gesture: UIPanGestureRecognizer) {
      guard let view = gesture.view else { return }
      let x = gesture.location(in: view).x

      switch gesture.state {
      case .began:
        self.onPanBegan?()
        self.onChanged(x)

      case .changed:
        self.onChanged(x)

      case .ended, .cancelled:
        self.onEnded?()

      default:
        break
      }
    }

    @objc
    func handleTap(_ gesture: UITapGestureRecognizer) {
      guard let view = gesture.view else { return }
      let x = gesture.location(in: view).x
      self.onTap?(x)
    }
  }

  var onPanBegan: (() -> Void)?
  var onChanged: (CGFloat) -> Void
  var onEnded: (() -> Void)?
  var onTap: ((CGFloat) -> Void)?

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear

    let pan = UIPanGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handlePan(_:)),
    )
    pan.delegate = context.coordinator
    view.addGestureRecognizer(pan)

    let tap = UITapGestureRecognizer(
      target: context.coordinator,
      action: #selector(Coordinator.handleTap(_:)),
    )
    view.addGestureRecognizer(tap)

    return view
  }

  func updateUIView(_: UIView, context: Context) {
    context.coordinator.onPanBegan = self.onPanBegan
    context.coordinator.onChanged = self.onChanged
    context.coordinator.onEnded = self.onEnded
    context.coordinator.onTap = self.onTap
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(onPanBegan: self.onPanBegan, onChanged: self.onChanged, onEnded: self.onEnded, onTap: self.onTap)
  }

}
