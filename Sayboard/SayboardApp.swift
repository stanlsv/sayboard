import FluidAudio

import SwiftUI
import TipKit
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate, @unchecked Sendable {

  @MainActor static var lastSourceApplication: String?

  @MainActor static var pendingPreShowHint = false

  static let deepLinkNotification = Notification.Name("app.sayboard.sceneDeepLink")

  static let preShowHintNotification = Notification.Name("app.sayboard.preShowHostReturnHint")

  func application(
    _: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void,
  ) {
    if BackgroundDownloadManager.ownsSession(identifier: identifier) {
      BackgroundDownloadManager.shared.storeSystemCompletionHandler(
        completionHandler,
        forSession: identifier,
      )
    }
  }

  func application(
    _: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions,
  ) -> UISceneConfiguration {
    DiagnosticLog.write(
      "app: launched on \(ProcessInfo.processInfo.operatingSystemVersionString), "
        + "backgroundANEBlocked=\(OperatingSystem.isBackgroundNeuralEngineBlocked)"
    )
    for ctx in options.urlContexts {
      let source = ctx.options.sourceApplication
      if let source, !source.isEmpty {
        Self.lastSourceApplication = source
      }
    }
    let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    config.delegateClass = SceneDelegate.self
    return config
  }
}

@MainActor
final class SceneDelegate: NSObject, UIWindowSceneDelegate {

  func scene(_: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    for ctx in connectionOptions.urlContexts {
      let source = ctx.options.sourceApplication
      if let source, !source.isEmpty {
        AppDelegate.lastSourceApplication = source
      }
      let url = ctx.url
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NotificationCenter.default.post(name: AppDelegate.deepLinkNotification, object: url)
      }
    }
  }

  func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for ctx in URLContexts {
      let source = ctx.options.sourceApplication
      let url = ctx.url
      if let source, !source.isEmpty {
        AppDelegate.lastSourceApplication = source
      }
      NotificationCenter.default.post(name: AppDelegate.deepLinkNotification, object: url)
    }
  }

  func sceneWillEnterForeground(_: UIScene) {
    guard
      OperatingSystem.isHostBundleIdBroken,
      SharedSettings().isKeyboardRequestRecent()
    else { return }
    AppDelegate.pendingPreShowHint = true
    NotificationCenter.default.post(name: AppDelegate.preShowHintNotification, object: nil)
  }
}

private enum DeepLinkValidator {
  @MainActor
  static func isFromKeyboard() -> Bool {
    let settings = SharedSettings()
    if let source = AppDelegate.lastSourceApplication, source == "app.sayboard.keyboard" {
      _ = settings.consumeKeyboardRequestIfRecent()
      return true
    }
    return settings.consumeKeyboardRequestIfRecent()
  }
}

@main
struct SayboardApp: App {

  init() {
    ModelHub.offlineMode = true
    ParakeetV3JointMigration.runIfNeeded()
    Self.configureDefaultLanguageIfNeeded()
    let settings = SharedSettings()
    settings.synchronize()
    settings.isSessionActive = false
    settings.isRecording = false
    settings.isModelLoading = false
    settings.dictationSessionToken = nil
    settings.mainAppHeartbeat = CFAbsoluteTimeGetCurrent()
    HistoryStore.shared.applyRetentionPolicy()
    ModelStorageManager.ensurePersistentCoreMLCache()
    try? Tips.resetDatastore()
    try? Tips.configure()

    let preShowHint = OperatingSystem.isHostBundleIdBroken && settings.isKeyboardRequestRecent()
    self._showsHostReturnHint = State(initialValue: preShowHint)
  }

  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      self.rootView
        .onReceive(NotificationCenter.default.publisher(for: .appLanguageChangeRequested)) { notification in
          self.handleLanguageChange(notification)
        }
    }
  }

  private static let defaultLanguage = AppLanguageConfig.fallback
  private static let overlayFadeDuration = 0.15
  private static let languageApplyDelay = 0.2
  private static let overlayDismissDelay = 0.15
  private static let dismissToBackgroundDelay = 0.05

  @StateObject private var speechService = SpeechRecognitionService()
  @StateObject private var playerService = AudioPlayerService()
  @StateObject private var downloadService = ModelDownloadService()
  @StateObject private var permissionService = PermissionService()
  @StateObject private var llmDownloadService = LLMDownloadService()
  @StateObject private var llmCoordinator = LLMProcessingCoordinator()
  @StateObject private var pipTutorialService = PiPTutorialService()
  @AppStorage(SharedKey.appLanguage) private var appLanguage = defaultLanguage
  @Environment(\.scenePhase) private var scenePhase
  @State private var isChangingLanguage = false
  @State private var pendingPiPTutorial: TutorialVideo?
  @State private var showsHostReturnHint = false

  private var rootView: some View {
    ZStack {
      self.mainTabContent
      self.hostReturnHintOverlay
      self.languageChangeOverlay
    }
  }

  private var mainTabContent: some View {
    MainTabView()
      .id(self.appLanguage)
      .environmentObject(self.speechService)
      .environmentObject(self.playerService)
      .environmentObject(self.downloadService)
      .environmentObject(self.permissionService)
      .environmentObject(self.llmDownloadService)
      .environmentObject(self.llmCoordinator)
      .environmentObject(self.pipTutorialService)
      .environment(\.locale, Locale(identifier: self.appLanguage))
      .onReceive(NotificationCenter.default.publisher(for: AppDelegate.deepLinkNotification)) { notification in
        if let url = notification.object as? URL { self.handleDeepLink(url) }
      }
      .onOpenURL { self.handleDeepLink($0) }
      .onAppear { self.handleAppear() }
      .onChange(of: self.scenePhase) { _, newPhase in self.handleScenePhaseChange(newPhase) }
      .onChange(of: self.downloadService.selectedVariant) { oldVariant, newVariant in
        guard oldVariant != newVariant else { return }
        Task { await self.handleSelectedVariantChange(oldVariant: oldVariant, newVariant: newVariant) }
      }
      .onChange(of: self.downloadService.downloadedVariants) {
        self.handleVariantStatesChange()
      }
      .onChange(of: self.speechService.isRecording) { _, isRecording in
        if !isRecording { self.showsHostReturnHint = false }
      }
      .onReceive(NotificationCenter.default.publisher(for: AppDelegate.preShowHintNotification)) { _ in
        MainActor.assumeIsolated {
          let pending = AppDelegate.pendingPreShowHint
          AppDelegate.pendingPreShowHint = false
          if pending || SharedSettings().isKeyboardRequestRecent() {
            self.showsHostReturnHint = true
          }
        }
      }
  }

  @ViewBuilder
  private var hostReturnHintOverlay: some View {
    if self.showsHostReturnHint {
      HostReturnHintOverlay { self.showsHostReturnHint = false }
        .environment(\.locale, Locale(identifier: self.appLanguage))
        .transition(.asymmetric(insertion: .identity, removal: .opacity))
    }
  }

  private var languageChangeOverlay: some View {
    Group {
      Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
      ProgressView().controlSize(.large)
    }
    .opacity(self.isChangingLanguage ? 1 : 0)
    .animation(self.isChangingLanguage ? nil : .easeOut(duration: Self.overlayFadeDuration), value: self.isChangingLanguage)
    .allowsHitTesting(self.isChangingLanguage)
  }

  private static func configureDefaultLanguageIfNeeded() {
    let defaults = UserDefaults.standard
    guard defaults.string(forKey: SharedKey.appLanguage) == nil else { return }
    defaults.set(
      AppLanguageConfig.resolveLanguage(from: Locale.preferredLanguages),
      forKey: SharedKey.appLanguage,
    )
  }

  private func handleAppear() {
    BackgroundDownloadManager.shared.restoreSession()
    self.applyGlobalAnimationSpeed()
    self.downloadService.verifyExistingModels()
    self.downloadService.checkForInterruptedDownloadOnLaunch()
    self.permissionService.refreshAll()
    self.speechService.downloadService = self.downloadService
    self.downloadService.modelLoader = self.speechService

    self.llmDownloadService.verifyExistingModels()
    self.llmDownloadService.checkForInterruptedDownloadOnLaunch()
    self.llmCoordinator.speechService = self.speechService
    self.llmCoordinator.downloadService = self.llmDownloadService
    self.llmCoordinator.setupObservers()

    let settings = SharedSettings()
    if settings.isLLMProcessing {
      settings.isLLMProcessing = false
    }
  }

  private func handleScenePhaseChange(_ phase: ScenePhase) {
    if phase == .background {
      self.showsHostReturnHint = false
    }
    if phase == .active {
      if let tutorial = self.pendingPiPTutorial {
        self.pendingPiPTutorial = nil
        self.pipTutorialService.playTutorial(tutorial, language: self.appLanguage, thenOpenSettings: true)
      } else {
        self.pipTutorialService.stopTutorial()
      }
      self.permissionService.refreshAll()
      self.downloadService.resumeInterruptedDownloadIfNeeded()
      self.llmDownloadService.resumeInterruptedDownloadIfNeeded()

      if self.permissionService.microphoneState == .denied, self.speechService.isRecording {
        Task { await self.speechService.stopRecording() }
      }
    }
  }

  private func handleSelectedVariantChange(oldVariant _: ModelVariant, newVariant: ModelVariant) async {
    if self.speechService.isRecording {
      await self.speechService.stopRecording()
    }

    guard self.downloadService.isDownloaded(newVariant) else {
      await self.speechService.deactivateCompletely()
      return
    }

    let folderURL = self.downloadService.modelFolderURL(for: newVariant)
    await self.speechService.reloadModel(variant: newVariant, folderURL: folderURL)
  }

  private func handleVariantStatesChange() {
    let selected = self.downloadService.selectedVariant
    if !self.downloadService.isDownloaded(selected), self.speechService.activeLoadState == .loaded {
      Task { await self.speechService.deactivateCompletely() }
    }
  }

  private func handleLanguageChange(_ notification: NotificationCenter.Publisher.Output) {
    guard
      let newLang = notification.object as? String,
      newLang != appLanguage
    else { return }

    self.isChangingLanguage = true

    DispatchQueue.main.asyncAfter(deadline: .now() + Self.languageApplyDelay) {
      self.appLanguage = newLang

      DispatchQueue.main.asyncAfter(deadline: .now() + Self.overlayDismissDelay) {
        self.isChangingLanguage = false
      }
    }
  }

  private func applyGlobalAnimationSpeed() {
    guard
      let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.windows.first
    else { return }
    window.layer.speed = AnimationSpeed.globalMultiplier
  }

  private func handleDeepLink(_ url: URL) {
    guard url.scheme == DeepLink.scheme else {
      return
    }

    switch url.host {
    case DeepLink.dictateHost:
      guard DeepLinkValidator.isFromKeyboard() else {
        return
      }
      self.handleDictateDeepLink()

    case DeepLink.stopHost:
      guard DeepLinkValidator.isFromKeyboard() else {
        return
      }
      Task { await self.speechService.stopRecording() }

    case DeepLink.settingsHost, DeepLink.llmModelsHost:
      break

    case DeepLink.modelsHost:
      self.activateSessionIfNeeded()

    case DeepLink.setupMicHost:
      if self.scenePhase == .active {
        self.pipTutorialService.playTutorial(.microphone, language: self.appLanguage, thenOpenSettings: true)
      } else {
        self.pendingPiPTutorial = .microphone
      }

    default:
      break
    }
  }

  private func startSessionIfNeeded() -> Bool {
    guard !self.speechService.session.isSessionActive else { return true }
    do {
      try self.speechService.session.startSession()
      return true
    } catch {
      NotificationCenter.default.post(name: .dictationFailedNoModel, object: nil)
      return false
    }
  }

  private func activateSessionIfNeeded() {
    guard !self.speechService.session.isSessionActive else { return }
    guard self.downloadService.hasUsableModel else { return }
    do {
      try self.speechService.session.startSession()
    } catch { }
  }

  private func handleDictateDeepLink() {
    SharedSettings().dictationSessionToken = UUID().uuidString

    if OperatingSystem.isHostBundleIdBroken {
      self.showsHostReturnHint = true
    }

    guard self.tryStartDictation() else {
      self.showsHostReturnHint = false
      return
    }

    if !OperatingSystem.isHostBundleIdBroken {
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissToBackgroundDelay) {
        self.returnToHostApp()
      }
    }

    Task { await self.loadModelInBackgroundIfNeeded() }
  }

  private func tryStartDictation() -> Bool {
    let isRec = self.speechService.isRecording

    guard !isRec else { return false }

    self.permissionService.refreshMicrophoneState()
    guard self.permissionService.microphoneState == .granted else {
      NotificationCenter.default.post(name: .dictationFailedNoMic, object: nil)
      return false
    }
    guard self.downloadService.hasUsableModel else {
      NotificationCenter.default.post(name: .dictationFailedNoModel, object: nil)
      return false
    }
    guard self.startSessionIfNeeded() else { return false }

    self.speechService.startCapture()
    guard self.speechService.isRecording else {
      return false
    }
    return true
  }

  private func loadModelInBackgroundIfNeeded() async {
    let _ = self.speechService.isRecording

    guard self.speechService.activeLoadState != .loaded else {
      return
    }

    var bgTaskID = UIBackgroundTaskIdentifier.invalid
    bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "ModelLoad") {
      UIApplication.shared.endBackgroundTask(bgTaskID)
      bgTaskID = .invalid
    }
    defer {
      if bgTaskID != .invalid {
        UIApplication.shared.endBackgroundTask(bgTaskID)
      }
    }

    let settings = SharedSettings()
    settings.isModelLoading = true
    defer { settings.isModelLoading = false }

    self.downloadService.verifyExistingModels()
    await self.speechService.loadModelIfAvailable(downloadService: self.downloadService)

    guard self.speechService.activeLoadState == .loaded else {
      TranscriptionBridge.postDarwinNotification(DarwinNotificationName.modelLoadingFailed)
      await self.speechService.stopRecording()
      self.speechService.session.endSession()
      NotificationCenter.default.post(name: .dictationFailedNoModel, object: nil)
      return
    }

    settings.hasPreparedModelOnce = true
  }

  private func returnToHostApp() {
    self.pipTutorialService.stopTutorial()
    let hostId = SharedSettings().hostBundleId
    guard let hostId else {
      return
    }
    let _ = HostAppOpener.open(bundleId: hostId)
  }

}
