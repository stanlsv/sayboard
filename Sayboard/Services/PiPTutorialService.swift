@preconcurrency import AVFoundation
import AVKit

import UIKit

@MainActor
final class PiPTutorialService: NSObject, ObservableObject {

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
    guard self.isActive else {
      if thenOpenSettings { Self.openSystemSettings() }
      return
    }
    guard thenOpenSettings else { return }

    self.pendingSettingsOpen = true
    let generation = self.generation
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.settingsFallbackDelay) { [weak self] in
      guard let self, self.generation == generation else { return }
      self.openSettingsIfPending()
    }
  }

  func stopTutorial() {
    guard self.isActive else { return }
    self.pipController?.delegate = nil
    self.pipController?.stopPictureInPicture()
    self.tearDown()
  }

  private static let settingsFallbackDelay: TimeInterval = 2

  private var player: AVPlayer?
  private var playerLayer: AVPlayerLayer?
  private var pipController: AVPictureInPictureController?
  private var hostView: UIView?
  private var looperObserver: Any?
  private var possibleObservation: NSKeyValueObservation?
  private var startRequested = false
  private var pendingSettingsOpen = false
  private var generation = 0

  private static func openSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
    }
  }

  private func configureAudioSessionForPiP() {
    guard !SharedSettings().isSessionActive else { return }
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, options: .mixWithOthers)
      try session.setActive(true)
    } catch { }
  }

  private func setupPlayer(url: URL) {
    self.generation += 1
    self.configureAudioSessionForPiP()

    let playerItem = AVPlayerItem(url: url)
    let newPlayer = AVPlayer(playerItem: playerItem)
    newPlayer.isMuted = true
    newPlayer.allowsExternalPlayback = false

    self.looperObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: playerItem,
      queue: .main,
    ) { [weak newPlayer] _ in
      newPlayer?.seek(to: .zero)
      newPlayer?.play()
    }

    let layer = AVPlayerLayer(player: newPlayer)
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
    self.possibleObservation = controller.observe(
      \.isPictureInPicturePossible,
      options: [.initial, .new],
    ) { @Sendable [weak self] _, change in
      guard change.newValue == true, let self else { return }
      Task { @MainActor in
        self.startIfPossible()
      }
    }

    newPlayer.play()
    self.isActive = true
  }

  private func startIfPossible() {
    guard
      self.isActive,
      !self.startRequested,
      let controller = self.pipController,
      controller.isPictureInPicturePossible
    else { return }
    self.startRequested = true
    controller.startPictureInPicture()
  }

  private func openSettingsIfPending() {
    guard self.pendingSettingsOpen else { return }
    self.pendingSettingsOpen = false
    Self.openSystemSettings()
  }

  private func tearDown() {
    guard self.isActive else { return }
    self.possibleObservation?.invalidate()
    self.possibleObservation = nil
    self.startRequested = false
    self.pendingSettingsOpen = false
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

extension PiPTutorialService: AVPictureInPictureControllerDelegate {

  nonisolated func pictureInPictureControllerWillStartPictureInPicture(
    _: AVPictureInPictureController
  ) { }

  nonisolated func pictureInPictureControllerDidStartPictureInPicture(
    _: AVPictureInPictureController
  ) {
    Task { @MainActor in
      self.openSettingsIfPending()
    }
  }

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
      self.openSettingsIfPending()
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
