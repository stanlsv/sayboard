import FluidAudio

import SwiftUI
import TipKit
import UIKit

// MARK: - AppDelegate

// AppDelegate -- Captures sourceApplication from URL opens via scene delegate.

// swiftlint:disable:next no_unchecked_sendable
final class AppDelegate: NSObject, UIApplicationDelegate, @unchecked Sendable {

  /// Bundle ID of the app that opened us via URL scheme.
  @MainActor static var lastSourceApplication: String?

  /// URL received in scene delegate, forwarded via notification.
  static let deepLinkNotification = Notification.Name("app.sayboard.sceneDeepLink")

  func application(
    _: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void,
  ) {
    if identifier == BackgroundDownloadManager.sessionIdentifier {
      BackgroundDownloadManager.shared.systemCompletionHandler = completionHandler
    }
  }

  func application(
    _: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions,
  ) -> UISceneConfiguration {
    // Capture sourceApplication from cold-launch URL contexts.
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

// MARK: - SceneDelegate

// SceneDelegate -- Intercepts URL opens to capture sourceApplication,
// then forwards the URL to the SwiftUI app via notification.

final class SceneDelegate: NSObject, UIWindowSceneDelegate {

  func scene(_: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    for ctx in connectionOptions.urlContexts {
      let source = ctx.options.sourceApplication
      if let source, !source.isEmpty {
        AppDelegate.lastSourceApplication = source
      }
      // Delay to let SwiftUI view hierarchy set up before delivering the deep link.
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
}

// MARK: - DeepLinkValidator

private enum DeepLinkValidator {
  @MainActor
  static func isFromKeyboard() -> Bool {
    if let source = AppDelegate.lastSourceApplication, source == "app.sayboard.keyboard" {
      return true
    }
    let settings = SharedSettings()
    settings.synchronize()
    if settings.keyboardRequestedDictation {
      settings.keyboardRequestedDictation = false
      return true
    }
    return false
  }
}

// MARK: - SayboardApp

@main
struct SayboardApp: App {

  // MARK: Lifecycle

  init() {
    Self.configureDefaultLanguageIfNeeded()
    let settings = SharedSettings()
    settings.isSessionActive = false
    settings.isRecording = false
    settings.isModelLoading = false
    settings.dictationSessionToken = nil
    HistoryStore.shared.applyRetentionPolicy()
    ModelStorageManager.ensurePersistentCoreMLCache()
    try? Tips.resetDatastore()
    try? Tips.configure()
  }

  // MARK: Internal

  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    WindowGroup {
      self.rootView
        .onReceive(NotificationCenter.default.publisher(for: .appLanguageChangeRequested)) { notification in
          self.handleLanguageChange(notification)
        }
    }
  }

  // MARK: Private

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

  private var rootView: some View {
    ZStack {
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

      self.languageChangeOverlay
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

    // Reset stale LLM processing flag (e.g. from a previous crash during inference)
    let settings = SharedSettings()
    if settings.isLLMProcessing {
      settings.isLLMProcessing = false
    }
  }

  private func handleScenePhaseChange(_ phase: ScenePhase) {
    if phase == .active {
      if let tutorial = self.pendingPiPTutorial {
        // Deep link requested a PiP tutorial before the app became active.
        // Play it now instead of stopping — the app is fully in foreground.
        self.pendingPiPTutorial = nil
        self.pipTutorialService.playTutorial(tutorial, language: self.appLanguage, thenOpenSettings: true)
      } else {
        self.pipTutorialService.stopTutorial()
      }
      self.permissionService.refreshAll()
      self.downloadService.resumeInterruptedDownloadIfNeeded()
      self.llmDownloadService.resumeInterruptedDownloadIfNeeded()

      // If mic was denied while recording, stop
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
      break // Handled by MainTabView navigation

    case DeepLink.modelsHost:
      self.activateSessionIfNeeded()

    case DeepLink.setupMicHost:
      if self.scenePhase == .active {
        self.pipTutorialService.playTutorial(.microphone, language: self.appLanguage, thenOpenSettings: true)
      } else {
        self.pendingPiPTutorial = .microphone
      }

    default:
    }
  }

  /// Starts a background audio session if not already active. Returns false on failure.
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
    } catch {
      // no-op
    }
  }

  private func handleDictateDeepLink() {
    // Set a session token so subsequent Darwin notifications (requestStop) are accepted
    SharedSettings().dictationSessionToken = UUID().uuidString
    let isRec = self.speechService.isRecording

    guard !isRec else { return }

    self.permissionService.refreshMicrophoneState()
    guard self.permissionService.microphoneState == .granted else {
      NotificationCenter.default.post(name: .dictationFailedNoMic, object: nil)
      return
    }

    guard self.downloadService.hasUsableModel else {
      NotificationCenter.default.post(name: .dictationFailedNoModel, object: nil)
      return
    }

    guard self.startSessionIfNeeded() else { return }

    self.speechService.startCapture()
    guard self.speechService.isRecording else {
      return
    }

    // Switch back to host app after capture is confirmed active.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.dismissToBackgroundDelay) {
      self.returnToHostApp()
    }

    Task { await self.loadModelInBackgroundIfNeeded() }
  }

  /// Loads the model at low priority if not already loaded. Posts Darwin notifications
  /// so the keyboard can track loading state.
  private func loadModelInBackgroundIfNeeded() async {
    let isRec = self.speechService.isRecording

    guard self.speechService.activeLoadState != .loaded else {
      return
    }

    // Prevent iOS from killing the process during long CoreML compilation.
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
  }

  private func returnToHostApp() {
    self.pipTutorialService.stopTutorial()
    let hostId = SharedSettings().hostBundleId
    guard let hostId else {
      return
    }
  }

}
