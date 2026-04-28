@preconcurrency import AVFoundation
import SwiftUI

// MARK: - AudioPlayerService

// AudioPlayerService -- Plays audio files with progress tracking

@MainActor
final class AudioPlayerService: ObservableObject {

  // MARK: Internal

  @Published var isPlaying = false
  @Published var duration: TimeInterval = 0
  @Published var currentFileURL: URL?

  /// Live playback position read directly from AVAudioPlayer each frame.
  /// Avoids @Published churn that causes SwiftUI to batch/skip redraws.
  var playbackTime: TimeInterval {
    self.player?.currentTime ?? 0
  }

  func play(url: URL) {
    if self.currentFileURL == url, let player {
      player.play()
      self.isPlaying = true
      return
    }

    self.stop()
    self.configureAudioSessionForPlayback()

    do {
      let newPlayer = try AVAudioPlayer(contentsOf: url)
      newPlayer.delegate = self.delegateAdapter
      newPlayer.prepareToPlay()
      newPlayer.play()
      player = newPlayer
      self.currentFileURL = url
      self.duration = newPlayer.duration
      self.isPlaying = true
    } catch {
      self.isPlaying = false
    }
  }

  func pause() {
    self.player?.pause()
    self.isPlaying = false
  }

  func stop() {
    self.player?.stop()
    self.player = nil
    self.isPlaying = false
    self.duration = 0
    self.currentFileURL = nil
  }

  func seek(to time: TimeInterval) {
    self.player?.currentTime = time
    self.objectWillChange.send()
  }

  func togglePlayback(url: URL) {
    if self.currentFileURL == url, self.isPlaying {
      self.pause()
    } else {
      self.play(url: url)
    }
  }

  // MARK: Private

  private var player: AVAudioPlayer?
  private lazy var delegateAdapter = PlayerDelegateAdapter { [weak self] in
    self?.handlePlaybackFinished()
  }

  private func configureAudioSessionForPlayback() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }

  private func handlePlaybackFinished() {
    self.isPlaying = false
    self.duration = 0
    self.currentFileURL = nil
  }
}

// MARK: - PlayerDelegateAdapter

private final class PlayerDelegateAdapter: NSObject, AVAudioPlayerDelegate {

  // MARK: Lifecycle

  init(onFinish: @escaping @MainActor () -> Void) {
    self.onFinish = onFinish
  }

  // MARK: Internal

  func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
    let callback = self.onFinish
    Task { @MainActor in
      callback()
    }
  }

  // MARK: Private

  private let onFinish: @MainActor () -> Void
}
