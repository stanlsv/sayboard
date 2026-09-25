import SwiftUI
import UIKit

struct MainTabView: View {

  let isBehindOnboarding: Bool

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
    .onChange(of: self.isBehindOnboarding) { _, isBehind in
      if !isBehind { self.activeBanner = self.recheckBanner() }
    }
    .onReceive(NotificationCenter.default.publisher(for: .purchaseScreenRequested)) { _ in
      guard !self.isBehindOnboarding else { return }
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
    .modifier(AIProcessingEnabledAlert())
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

  private static var isSpeechModelDownloading: Bool {
    ModelVariant.allCases.contains {
      BackgroundDownloadManager.shared.hasActiveDownload(variantRawValue: $0.rawValue, downloadType: .stt)
    }
  }

  @EnvironmentObject private var permissionService: PermissionService
  @EnvironmentObject private var pipTutorialService: PiPTutorialService
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
      guard !self.isBehindOnboarding else { return }
      self.selectedTab = TabID.models.rawValue
      self.activeBanner = .noModel
    }
    .onReceive(NotificationCenter.default.publisher(for: .dictationFailedNoMic)) { _ in
      guard !self.isBehindOnboarding else { return }
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
          HistoryListView()
        }
      }

      Tab("Models", image: "tab-models", value: TabID.models.rawValue) {
        NavigationStack {
          ModelsView()
            .equatable()
        }
      }

      Tab("Settings", image: "tab-settings", value: TabID.settings.rawValue) {
        NavigationStack {
          SettingsView()
            .equatable()
        }
        .id(self.settingsStackID)
      }
    }
  }

  private var legacyTabs: some View {
    TabView(selection: self.$selectedTab) {
      NavigationStack {
        HistoryListView()
      }
      .tabItem {
        Label("History", image: "tab-history")
      }
      .tag(TabID.history.rawValue)

      NavigationStack {
        ModelsView()
          .equatable()
      }
      .tabItem {
        Label("Models", image: "tab-models")
      }
      .tag(TabID.models.rawValue)

      NavigationStack {
        SettingsView()
          .equatable()
      }
      .id(self.settingsStackID)
      .tabItem {
        Label("Settings", image: "tab-settings")
      }
      .tag(TabID.settings.rawValue)
    }
  }

  private static func initialBanner() -> SetupBanner? {
    let settings = SharedSettings()
    let checklist = SetupChecklist(
      microphoneGranted: settings.isMicrophoneAuthorized,
      keyboardAdded: PermissionService.isKeyboardAddedSync(),
      fullAccessGranted: PermissionService.hasFullAccessSync(),
      hasUsableModel: settings.hasUsableModel,
    )
    return Self.banner(for: checklist, isDictationLocked: settings.isDictationLocked)
  }

  private static func banner(for checklist: SetupChecklist, isDictationLocked: Bool) -> SetupBanner? {
    guard UserDefaults.standard.bool(forKey: SharedKey.hasCompletedOnboarding) else { return nil }
    let postponed = OnboardingRecordStore().load().postponedSteps
    if !checklist.microphoneGranted, !postponed.contains(.microphone) { return .micDenied }
    if !checklist.keyboardAdded, !postponed.contains(.keyboard) { return .keyboardMissing }
    if !checklist.fullAccessGranted, !postponed.contains(.keyboard) { return .fullAccessMissing }
    if !checklist.hasUsableModel, !postponed.contains(.languages), !Self.isSpeechModelDownloading {
      return SharedSettings().parakeetV3NeedsRedownload ? .modelRemovedByUpdate : .noModel
    }
    return isDictationLocked ? .freeDictationUsedUp : nil
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
    let checklist = SetupChecklist(permissions: self.permissionService, hasUsableModel: SharedSettings().hasUsableModel)
    return Self.banner(for: checklist, isDictationLocked: self.isDictationLocked)
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
    guard url.scheme == DeepLink.scheme, !self.isBehindOnboarding else { return }
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

private struct AIProcessingEnabledAlert: ViewModifier {

  func body(content: Content) -> some View {
    content.alert(
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

  @EnvironmentObject private var llmDownloadService: LLMDownloadService

}
