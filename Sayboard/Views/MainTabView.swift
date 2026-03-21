import SwiftUI
import UIKit

// MARK: - MainTabView

struct MainTabView: View {

  // MARK: Internal

  var body: some View {
    ZStack {
      self.tabsWithHandlers

      if let banner = self.activeBanner {
        self.bannerView(for: banner)
          .zIndex(1)
      }
    }
    .task {
      self.activeBanner = Self.initialBanner()
    }
  }

  // MARK: Private

  private enum TabID: String {
    case history
    case models
    case settings
  }

  private enum SetupBanner {
    case micDenied
    case keyboardMissing
    case fullAccessMissing
    case noModel

    // MARK: Internal

    var title: LocalizedStringKey {
      switch self {
      case .micDenied: "No Microphone Access"
      case .keyboardMissing: "Keyboard Not Added"
      case .fullAccessMissing: "Full Access Required"
      case .noModel: "No Model Installed"
      }
    }

    var subtitle: LocalizedStringKey {
      switch self {
      case .micDenied: "Enable microphone access so Sayboard can hear you. Your audio never leaves your device."
      case .keyboardMissing: "Sayboard needs to be added as a keyboard to use voice dictation in any app."
      case .fullAccessMissing: "Sayboard needs Full Access to hear your voice from the keyboard."
      case .noModel: "Download a speech recognition model to start using voice input."
      }
    }
  }

  private static let settingsTabIndex = 2

  private static let defaultLanguage = AppLanguageConfig.fallback

  @EnvironmentObject private var permissionService: PermissionService
  @EnvironmentObject private var pipTutorialService: PiPTutorialService
  @AppStorage(SharedKey.appLanguage) private var appLanguage = defaultLanguage
  @SceneStorage("selectedTab") private var selectedTab = TabID.history.rawValue
  @State private var activeBanner: SetupBanner?

  private var tabsWithHandlers: some View {
    Group {
      if #available(iOS 18.0, *) {
        self.liquidGlassTabs
      } else {
        self.legacyTabs
      }
    }
    .onOpenURL { url in
      self.handleTabDeepLink(url)
    }
    .onReceive(NotificationCenter.default.publisher(for: .dictationFailedNoModel)) { _ in
      self.selectedTab = TabID.models.rawValue
      self.activeBanner = .noModel
    }
    .onReceive(NotificationCenter.default.publisher(for: .dictationFailedNoMic)) { _ in
      self.selectedTab = TabID.settings.rawValue
      self.activeBanner = .micDenied
    }
    .onReceive(self.permissionService.objectWillChange.receive(on: RunLoop.main)) { _ in
      self.recheckActiveBanner()
    }
    .background {
      TabBarTapInterceptor(settingsTabIndex: Self.settingsTabIndex) { }
    }
  }

  @available(iOS 18.0, *)
  private var liquidGlassTabs: some View {
    TabView(selection: self.$selectedTab) {
      Tab("History", image: "tab-history", value: TabID.history.rawValue) {
        NavigationStack {
          ContentView()
        }
      }

      Tab("Models", image: "tab-models", value: TabID.models.rawValue) {
        NavigationStack {
          ModelsView()
        }
      }

      Tab("Settings", image: "tab-settings", value: TabID.settings.rawValue) {
        NavigationStack {
          SettingsView()
        }
      }
    }
  }

  private var legacyTabs: some View {
    TabView(selection: self.$selectedTab) {
      NavigationStack {
        ContentView()
      }
      .tabItem {
        Label("History", image: "tab-history")
      }
      .tag(TabID.history.rawValue)

      NavigationStack {
        ModelsView()
      }
      .tabItem {
        Label("Models", image: "tab-models")
      }
      .tag(TabID.models.rawValue)

      NavigationStack {
        SettingsView()
      }
      .tabItem {
        Label("Settings", image: "tab-settings")
      }
      .tag(TabID.settings.rawValue)
    }
  }

  /// Cold-launch banner check (static, no environment objects available).
  private static func initialBanner() -> SetupBanner? {
    let settings = SharedSettings()
    if !settings.isMicrophoneAuthorized {
      return .micDenied
    }
    if !PermissionService.isKeyboardAddedSync() {
      return .keyboardMissing
    }
    if !PermissionService.hasFullAccessSync() {
      return .fullAccessMissing
    }
    if !settings.hasUsableModel {
      return .noModel
    }
    return nil
  }

  private static func tutorialVideoForBanner(_ banner: SetupBanner) -> TutorialVideo? {
    switch banner {
    case .micDenied: .microphone
    case .keyboardMissing: .addKeyboard
    case .fullAccessMissing: .fullAccess
    case .noModel: nil
    }
  }

  private func recheckActiveBanner() {
    guard self.activeBanner != nil else { return }
    self.activeBanner = self.recheckBanner()
  }

  /// Recheck using live PermissionService values
  /// (refreshed by SayboardApp.handleScenePhaseChange on foreground return).
  private func recheckBanner() -> SetupBanner? {
    if self.permissionService.microphoneState != .granted {
      return .micDenied
    }
    if !self.permissionService.isKeyboardAdded {
      return .keyboardMissing
    }
    if !self.permissionService.hasFullAccess {
      return .fullAccessMissing
    }
    if !SharedSettings().hasUsableModel {
      return .noModel
    }
    return nil
  }

  private func bannerView(for banner: SetupBanner) -> SetupBannerView {
    let primaryAction =
      if banner == .noModel {
        SetupBannerAction(title: "Open Models", style: .primary) {
          self.activeBanner = nil
          self.selectedTab = TabID.models.rawValue
        }
      } else {
        SetupBannerAction(title: "Open Settings", style: .primary) {
          self.activeBanner = nil
          if let video = Self.tutorialVideoForBanner(banner) {
            self.pipTutorialService.playTutorial(video, language: self.appLanguage, thenOpenSettings: true)
          } else {
            self.openSystemSettings()
          }
        }
      }
    return SetupBannerView(
      title: banner.title,
      subtitle: banner.subtitle,
      actions: [primaryAction],
      tutorial: self.tutorialView(for: banner),
    )
  }

  private func tutorialView(for banner: SetupBanner) -> AnyView? {
    switch banner {
    case .micDenied:
      AnyView(MicrophoneTutorialView())
    case .keyboardMissing:
      AnyView(FullAccessTutorialView(includeFullAccessRow: false))
    case .fullAccessMissing:
      AnyView(FullAccessTutorialView())
    case .noModel:
      nil
    }
  }

  private func openSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
    }
  }

  private func handleTabDeepLink(_ url: URL) {
    guard url.scheme == DeepLink.scheme else { return }
    switch url.host {
    case DeepLink.settingsHost:
      self.selectedTab = TabID.settings.rawValue

    case DeepLink.modelsHost:
      self.selectedTab = TabID.models.rawValue
      self.activeBanner = .noModel

    case DeepLink.llmModelsHost:
      self.selectedTab = TabID.models.rawValue

    case DeepLink.setupMicHost:
      self.activeBanner = nil

    default:
      break
    }
  }
}

// MARK: - TabBarTapInterceptor

/// Finds the UITabBar in the window hierarchy and attaches a tap gesture recognizer
/// to detect rapid taps on the Settings tab (Easter egg trigger).
private struct TabBarTapInterceptor: UIViewRepresentable {

  final class InterceptorView: UIView {

    // MARK: Lifecycle

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

    // MARK: Internal

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

    // MARK: Private

    private let coordinator: Coordinator
  }

  @MainActor
  final class Coordinator: NSObject, UIGestureRecognizerDelegate {

    // MARK: Lifecycle

    init(settingsTabIndex: Int, onSettingsTapped: @escaping () -> Void) {
      self.settingsTabIndex = settingsTabIndex
      self.onSettingsTapped = onSettingsTapped
    }

    // MARK: Internal

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

    // MARK: Private

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
