@preconcurrency import AVFoundation
import AVKit

import UIKit

// PiPTutorialService -- Plays bundled tutorial videos in Picture-in-Picture mode
// so they float over iOS Settings while the user follows setup instructions.
// AVFoundation types lack Sendable conformance in the SDK, so @preconcurrency
// is needed to suppress false positives in this @MainActor-isolated class.

// MARK: - PiPTutorialService

@MainActor
final class PiPTutorialService: NSObject, ObservableObject {

  // MARK: Internal

  @Published private(set) var isActive = false

  func playTutorial(_ tutorial: TutorialVideo, language: String, thenOpenSettings: Bool) {
    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      if thenOpenSettings { Self.openSystemSettings() }
      return
    }

    guard let videoURL = tutorial.url(for: language) else {
      if thenOpenSettings { Self.openSystemSettings() }
      return
    }

    self.stopTutorial()
    self.setupPlayer(url: videoURL)

    // Delay PiP start slightly to let AVPlayerLayer attach and render a frame.
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.pipStartDelay) { [weak self] in
      guard let self, self.isActive else { return }
      self.startPiP()
      if thenOpenSettings {
        // Open Settings after PiP has had time to initialize.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settingsOpenDelay) {
          Self.openSystemSettings()
        }
      }
    }
  }

  func stopTutorial() {
    guard self.isActive else { return }
    self.pipController?.stopPictureInPicture()
    // Teardown happens in pictureInPictureControllerDidStopPictureInPicture delegate.
    // If there is no active PiP session yet, tear down immediately.
    if self.pipController?.isPictureInPictureActive != true {
      self.tearDown()
    }
  }

  // MARK: Private

  private static let pipStartDelay: TimeInterval = 0.3
  private static let pipRetryDelay: TimeInterval = 0.3
  private static let settingsOpenDelay: TimeInterval = 0.2

  private var player: AVPlayer?
  private var playerLayer: AVPlayerLayer?
  private var pipController: AVPictureInPictureController?
  private var hostView: UIView?
  private var looperObserver: Any?

  private static func openSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
    }
  }

  /// Ensure the audio session supports PiP playback. Without an active audio session,
  /// AVPictureInPictureController may report isPictureInPicturePossible = false.
  /// Uses .playback + .mixWithOthers so it doesn't interfere with recording.
  private func configureAudioSessionForPiP() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, options: .mixWithOthers)
      try session.setActive(true)
    } catch {
      // no-op
    }
  }

  private func setupPlayer(url: URL) {
    self.configureAudioSessionForPiP()

    let playerItem = AVPlayerItem(url: url)
    let newPlayer = AVPlayer(playerItem: playerItem)
    newPlayer.isMuted = true
    newPlayer.allowsExternalPlayback = false

    // Loop: seek to start when reaching end.
    self.looperObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main,
    ) { [weak newPlayer] _ in
      newPlayer?.seek(to: .zero)
      newPlayer?.play()
    }

    // Create a hidden host view to anchor AVPlayerLayer.
    let layer = AVPlayerLayer(player: newPlayer)
    // PiP requires a non-zero frame for the player layer.
    layer.frame = CGRect(x: 0, y: 0, width: 568, height: 320)
    layer.videoGravity = .resizeAspect

    let view = UIView(frame: layer.frame)
    view.isHidden = true
    view.layer.addSublayer(layer)

    if
      let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let window = windowScene.keyWindow
    {
      window.addSubview(view)
    }

    self.player = newPlayer
    self.playerLayer = layer
    self.hostView = view

    guard let controller = AVPictureInPictureController(playerLayer: layer) else {
      self.tearDown()
      return
    }
    controller.delegate = self
    controller.canStartPictureInPictureAutomaticallyFromInline = false
    self.pipController = controller

    newPlayer.play()
    self.isActive = true
  }

  private func startPiP() {
    guard let controller = self.pipController else {
      return
    }
    guard controller.isPictureInPicturePossible else {
      // Retry once after a short delay -- AVPictureInPictureController
      // may need an extra runloop cycle after AVPlayerLayer renders.
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.pipRetryDelay) { [weak self] in
        guard let self, self.isActive, self.pipController === controller else { return }
        if controller.isPictureInPicturePossible {
          controller.startPictureInPicture()
        } else { }
      }
      return
    }
    controller.startPictureInPicture()
  }

  private func tearDown() {
    guard self.isActive else { return }
    self.pipController?.delegate = nil
    self.pipController = nil
    self.player?.pause()
    if let observer = self.looperObserver {
      NotificationCenter.default.removeObserver(observer)
      self.looperObserver = nil
    }
    self.playerLayer?.removeFromSuperlayer()
    self.playerLayer = nil
    self.hostView?.removeFromSuperview()
    self.hostView = nil
    self.player = nil
    self.isActive = false
  }

}

// MARK: AVPictureInPictureControllerDelegate

extension PiPTutorialService: AVPictureInPictureControllerDelegate {

  nonisolated func pictureInPictureControllerWillStartPictureInPicture(
    _: AVPictureInPictureController
  ) { }

  nonisolated func pictureInPictureControllerDidStartPictureInPicture(
    _: AVPictureInPictureController
  ) { }

  nonisolated func pictureInPictureControllerWillStopPictureInPicture(
    _: AVPictureInPictureController
  ) { }

  nonisolated func pictureInPictureControllerDidStopPictureInPicture(
    _: AVPictureInPictureController
  ) {
    Task { @MainActor in
      self.tearDown()
    }
  }

  nonisolated func pictureInPictureController(
    _: AVPictureInPictureController,
    failedToStartPictureInPictureWithError _: Error,
  ) {
    Task { @MainActor in
      self.tearDown()
    }
  }

  nonisolated func pictureInPictureController(
    _: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void,
  ) {
    completionHandler(true)
  }
}
