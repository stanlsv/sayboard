import SwiftUI
import UIKit

struct MainTabView: View {

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
    .onReceive(NotificationCenter.default.publisher(for: .purchaseScreenRequested)) { _ in
      self.isPurchaseScreenPresented = true
    }
    .onChange(of: self.isDictationLocked) { _, isLocked in
      if isLocked {
        if self.activeBanner == nil { self.activeBanner = .freeDictationUsedUp }
      } else {
        self.recheckActiveBanner()
      }
    }
    .onChange(of: self.entitlementStatus) { _, status in
      if status == .unlocked { self.isPurchaseScreenPresented = false }
    }
    .purchaseScreen(isPresented: self.$isPurchaseScreenPresented)
    .alert(
      "AI Text Processing Enabled",
      isPresented: self.$llmDownloadService.didEnableByDownload,
    ) {
      Button("OK") { }
        .keyboardShortcut(.defaultAction)
      Button("Turn Off") {
        SharedSettings().llmEnabled = false
      }
    } message: {
      Text("The AI button is now on the keyboard.")
    }
  }

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
    case modelRemovedByUpdate
    case freeDictationUsedUp

    var title: LocalizedStringKey {
      switch self {
      case .micDenied: "No Microphone Access"
      case .keyboardMissing: "Keyboard Not Added"
      case .fullAccessMissing: "Full Access Required"
      case .noModel: "No Model Installed"
      case .modelRemovedByUpdate: "Model Update Required"
      case .freeDictationUsedUp: "Free Dictation Used Up"
      }
    }

    var subtitle: LocalizedStringKey {
      switch self {
      case .micDenied: "Enable microphone access so Sayboard can hear you. Your audio never leaves your device."
      case .keyboardMissing: "Sayboard needs to be added as a keyboard to use voice dictation in any app."
      case .fullAccessMissing: "Sayboard needs Full Access to hear your voice from the keyboard."
      case .noModel: "Download a speech recognition model to start using voice input."
      case .modelRemovedByUpdate: "Parakeet v3 has been updated and needs to be downloaded again."
      case .freeDictationUsedUp: "Support Sayboard with a one-time purchase to keep dictating."
      }
    }
  }

  private static let settingsTabIndex = 2

  private static let defaultLanguage = AppLanguageConfig.fallback

  @EnvironmentObject private var permissionService: PermissionService
  @EnvironmentObject private var pipTutorialService: PiPTutorialService
  @EnvironmentObject private var llmDownloadService: LLMDownloadService
  @AppStorage(SharedKey.appLanguage) private var appLanguage = defaultLanguage
  @AppStorage(SharedKey.entitlementStatus, store: UserDefaults(suiteName: AppGroup.identifier))
  private var entitlementStatus = EntitlementStatus.unknown
  @AppStorage(SharedKey.freeWordsUsed, store: UserDefaults(suiteName: AppGroup.identifier))
  private var freeWordsUsed = 0
  @Environment(\.scenePhase) private var scenePhase
  @SceneStorage("selectedTab") private var selectedTab = TabID.history.rawValue
  @State private var activeBanner: SetupBanner?
  @State private var settingsStackID = UUID()
  @State private var isPurchaseScreenPresented = false

  private var isDictationLocked: Bool {
    StoreBuild.isEnabled
      && DictationAllowance(status: self.entitlementStatus, wordsUsed: self.freeWordsUsed).isExhausted
  }

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
      self.resetSettingsStackIfIdle()
      self.selectedTab = TabID.history.rawValue
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
        .id(self.settingsStackID)
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
      .id(self.settingsStackID)
      .tabItem {
        Label("Settings", image: "tab-settings")
      }
      .tag(TabID.settings.rawValue)
    }
  }

  private static func initialBanner() -> SetupBanner? {
    let onboardingCompleted = UserDefaults.standard.bool(forKey: SharedKey.hasCompletedOnboarding)
    guard onboardingCompleted else { return nil }
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
      return settings.parakeetV3NeedsRedownload ? .modelRemovedByUpdate : .noModel
    }
    return settings.isDictationLocked ? .freeDictationUsedUp : nil
  }

  private static func tutorialVideoForBanner(_ banner: SetupBanner) -> TutorialVideo? {
    switch banner {
    case .micDenied: .microphone
    case .keyboardMissing: .addKeyboard
    case .fullAccessMissing: .fullAccess
    case .noModel, .modelRemovedByUpdate, .freeDictationUsedUp: nil
    }
  }

  private func recheckActiveBanner() {
    guard self.activeBanner != nil else { return }
    self.activeBanner = self.recheckBanner()
  }

  private func recheckBanner() -> SetupBanner? {
    let onboardingCompleted = UserDefaults.standard.bool(forKey: SharedKey.hasCompletedOnboarding)
    guard onboardingCompleted else { return nil }
    if self.permissionService.microphoneState != .granted {
      return .micDenied
    }
    if !self.permissionService.isKeyboardAdded {
      return .keyboardMissing
    }
    if !self.permissionService.hasFullAccess {
      return .fullAccessMissing
    }
    let settings = SharedSettings()
    if !settings.hasUsableModel {
      return settings.parakeetV3NeedsRedownload ? .modelRemovedByUpdate : .noModel
    }
    return self.isDictationLocked ? .freeDictationUsedUp : nil
  }

  private func bannerView(for banner: SetupBanner) -> SetupBannerView {
    SetupBannerView(
      title: banner.title,
      subtitle: banner.subtitle,
      actions: self.bannerActions(for: banner),
      tutorial: self.tutorialView(for: banner),
    )
  }

  private func bannerActions(for banner: SetupBanner) -> [SetupBannerAction] {
    switch banner {
    case .noModel, .modelRemovedByUpdate:
      [
        SetupBannerAction(title: "Open Models", style: .primary) {
          self.activeBanner = nil
          self.selectedTab = TabID.models.rawValue
        }
      ]

    case .freeDictationUsedUp:
      [
        SetupBannerAction(title: "Get Full Version", style: .primary) {
          self.isPurchaseScreenPresented = true
        },
        SetupBannerAction(title: "Not Now", style: .secondary) {
          self.activeBanner = nil
        },
      ]

    case .micDenied, .keyboardMissing, .fullAccessMissing:
      [
        SetupBannerAction(title: "Open Settings", style: .primary) {
          self.activeBanner = nil
          if let video = Self.tutorialVideoForBanner(banner) {
            self.pipTutorialService.playTutorial(video, language: self.appLanguage, thenOpenSettings: true)
          } else {
            self.openSystemSettings()
          }
        }
      ]
    }
  }

  private func tutorialView(for banner: SetupBanner) -> AnyView? {
    switch banner {
    case .micDenied:
      AnyView(MicrophoneTutorialView())
    case .keyboardMissing:
      AnyView(FullAccessTutorialView(includeFullAccessRow: false))
    case .fullAccessMissing:
      AnyView(FullAccessTutorialView())
    case .noModel, .modelRemovedByUpdate, .freeDictationUsedUp:
      nil
    }
  }

  private func openSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
    }
  }

  private func resetSettingsStackIfIdle() {
    guard self.scenePhase != .active || self.selectedTab != TabID.settings.rawValue else { return }
    self.settingsStackID = UUID()
  }

  private func handleTabDeepLink(_ url: URL) {
    guard url.scheme == DeepLink.scheme else { return }
    switch url.host {
    case DeepLink.settingsHost:
      self.resetSettingsStackIfIdle()
      self.selectedTab = TabID.settings.rawValue

    case DeepLink.modelsHost:
      self.selectedTab = TabID.models.rawValue
      self.activeBanner = .noModel

    case DeepLink.setupMicHost:
      self.activeBanner = nil

    case DeepLink.unlockHost:
      if self.isDictationLocked { self.isPurchaseScreenPresented = true }

    default:
      break
    }
  }
}

private struct TabBarTapInterceptor: UIViewRepresentable {

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
