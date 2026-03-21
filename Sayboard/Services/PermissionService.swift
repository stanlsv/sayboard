import AVFoundation
import UIKit

// MARK: - MicrophonePermissionState

enum MicrophonePermissionState {
  case undetermined
  case denied
  case granted
}

// MARK: - PermissionService

// PermissionService -- Single source of truth for app permissions (mic, keyboard)

@MainActor
final class PermissionService: ObservableObject {

  // MARK: Internal

  @Published private(set) var microphoneState = MicrophonePermissionState.undetermined
  @Published private(set) var isKeyboardAdded = false
  @Published private(set) var hasFullAccess = false

  /// Check full access synchronously without PermissionService instance.
  /// Uses UIInputViewController().hasFullAccess (KeyboardKit approach).
  static func hasFullAccessSync() -> Bool {
    UIInputViewController().hasFullAccess
  }

  static func isKeyboardAddedSync() -> Bool {
    let keyboards = UserDefaults.standard.stringArray(forKey: self.appleKeyboardsKey) ?? []
    return keyboards.contains(self.sayboardKeyboardId)
  }

  func refreshAll() {
    self.refreshMicrophoneState()
    self.refreshKeyboardAdded()
    self.refreshFullAccess()
    self.registerFullAccessObserverIfNeeded()
  }

  func refreshMicrophoneState() {
    let permission = AVAudioApplication.shared.recordPermission
    switch permission {
    case .granted:
      self.microphoneState = .granted
    case .denied:
      self.microphoneState = .denied
    case .undetermined:
      self.microphoneState = .undetermined
    @unknown default:
      self.microphoneState = .denied
    }
    self.settings.isMicrophoneAuthorized = self.microphoneState == .granted
  }

  func requestMicrophonePermission() {
    AVAudioApplication.requestRecordPermission { [weak self] granted in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.microphoneState = granted ? .granted : .denied
        self.settings.isMicrophoneAuthorized = granted
      }
    }
  }

  func refreshKeyboardAdded() {
    let keyboards = UserDefaults.standard.stringArray(forKey: Self.appleKeyboardsKey) ?? []
    self.isKeyboardAdded = keyboards.contains(Self.sayboardKeyboardId)
  }

  /// Read full access directly via UIInputViewController (KeyboardKit approach).
  /// This is undocumented from the main app but shipped in production by KeyboardKit.
  func refreshFullAccess() {
    let value = UIInputViewController().hasFullAccess
    self.hasFullAccess = value
  }

  // MARK: Private

  private static let appleKeyboardsKey = "AppleKeyboards"
  private static let sayboardKeyboardId = "app.sayboard.keyboard"

  private let settings = SharedSettings()
  private var fullAccessObserver: DarwinNotificationObserver?

  /// Darwin observer for real-time updates when keyboard extension syncs full access.
  private func registerFullAccessObserverIfNeeded() {
    guard self.fullAccessObserver == nil else { return }
    self.fullAccessObserver = TranscriptionBridge.observeDarwinNotification(
      DarwinNotificationName.fullAccessChanged
    ) { [weak self] in
      DispatchQueue.main.async {
        self?.refreshFullAccess()
      }
    }
  }
}
