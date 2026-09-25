
import SwiftUI
import UIKit

struct TabBarTapInterceptor: UIViewRepresentable {

  final class InterceptorView: UIView {

    init(coordinator: Coordinator) {
      self.coordinator = coordinator
      super.init(frame: .zero)
      self.isHidden = true
      self.isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
      fatalError("init(coder:) is not supported")
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      guard let window, !self.coordinator.isInstalled else { return }
      self.coordinator.install(in: window)
      if !self.coordinator.isInstalled {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
          guard let self, let window = self.window, !self.coordinator.isInstalled else { return }
          self.coordinator.install(in: window)
        }
      }
    }

    private let coordinator: Coordinator
  }

  @MainActor
  final class Coordinator: NSObject, UIGestureRecognizerDelegate {

    init(settingsTabIndex: Int, onSettingsTapped: @escaping () -> Void) {
      self.settingsTabIndex = settingsTabIndex
      self.onSettingsTapped = onSettingsTapped
    }

    private(set) var isInstalled = false

    func install(in window: UIWindow) {
      guard let tabBar = Self.findTabBar(in: window) else { return }
      let tap = UITapGestureRecognizer(target: self, action: #selector(self.tabBarTapped(_:)))
      tap.cancelsTouchesInView = false
      tap.delegate = self
      tabBar.addGestureRecognizer(tap)
      self.isInstalled = true
    }

    func gestureRecognizer(
      _: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer,
    ) -> Bool {
      true
    }

    private static let requiredTapCount = 7
    private static let tapWindowSeconds: TimeInterval = 3

    private let settingsTabIndex: Int
    private let onSettingsTapped: () -> Void
    private var tapTimestamps = [Date]()

    private static func findTabBar(in view: UIView) -> UITabBar? {
      if let tabBar = view as? UITabBar {
        return tabBar
      }
      for subview in view.subviews {
        if let found = findTabBar(in: subview) {
          return found
        }
      }
      return nil
    }

    @objc
    private func tabBarTapped(_ gesture: UITapGestureRecognizer) {
      guard let tabBar = gesture.view as? UITabBar else { return }
      let itemCount = tabBar.items?.count ?? 1
      let tabWidth = tabBar.bounds.width / CGFloat(itemCount)
      let tappedIndex = Int(gesture.location(in: tabBar).x / tabWidth)
      guard tappedIndex == self.settingsTabIndex else { return }
      self.handleSettingsTap()
    }

    private func handleSettingsTap() {
      let now = Date()
      let cutoff = now.addingTimeInterval(-Self.tapWindowSeconds)
      self.tapTimestamps = self.tapTimestamps.filter { $0 > cutoff }
      self.tapTimestamps.append(now)
      if self.tapTimestamps.count >= Self.requiredTapCount {
        self.tapTimestamps.removeAll()
        SharedSettings().useCustomSpaceBar.toggle()
        self.onSettingsTapped()
      }
    }
  }

  let settingsTabIndex: Int
  let onSettingsTapped: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(settingsTabIndex: self.settingsTabIndex, onSettingsTapped: self.onSettingsTapped)
  }

  func makeUIView(context: Context) -> InterceptorView {
    InterceptorView(coordinator: context.coordinator)
  }

  func updateUIView(_: InterceptorView, context _: Context) { }

}
