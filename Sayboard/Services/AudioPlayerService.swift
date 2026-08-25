@preconcurrency import AVFoundation
import SwiftUI

@MainActor
final class AudioPlayerService: ObservableObject {

  @Published var isPlaying = false
  @Published var duration: TimeInterval = 0
  @Published var currentFileURL: URL?

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

private final class PlayerDelegateAdapter: NSObject, AVAudioPlayerDelegate {

  init(onFinish: @escaping @MainActor () -> Void) {
    self.onFinish = onFinish
  }

  func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
    let callback = self.onFinish
    Task { @MainActor in
      callback()
    }
  }

  private let onFinish: @MainActor () -> Void
}
