@preconcurrency import AVFoundation
import SwiftUI

// MARK: - AudioPlayerService

// AudioPlayerService -- Plays audio files with progress tracking

@MainActor
final class AudioPlayerService: ObservableObject {

  // MARK: Internal

  @Published var isPlaying = false
  @Published var currentTime: TimeInterval = 0
  @Published var duration: TimeInterval = 0
  @Published var currentFileURL: URL?

  func play(url: URL) {
    if self.currentFileURL == url, let player {
      player.play()
      self.isPlaying = true
      self.startProgressTimer()
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
      self.currentTime = 0
      self.isPlaying = true
      self.startProgressTimer()
    } catch {
      self.isPlaying = false
    }
  }

  func pause() {
    self.player?.pause()
    self.isPlaying = false
    self.stopProgressTimer()
  }

  func stop() {
    self.player?.stop()
    self.player = nil
    self.isPlaying = false
    self.currentTime = 0
    self.duration = 0
    self.currentFileURL = nil
    self.stopProgressTimer()
  }

  func seek(to time: TimeInterval) {
    self.player?.currentTime = time
    self.currentTime = time
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
  private var displayLink: CADisplayLink?
  private var displayLinkProxy: DisplayLinkProxy?
  private lazy var delegateAdapter = PlayerDelegateAdapter { [weak self] in
    self?.handlePlaybackFinished()
  }

  private func startProgressTimer() {
    self.stopProgressTimer()
    let proxy = DisplayLinkProxy { [weak self] in
      guard let self, let player else { return }
      self.currentTime = player.currentTime
    }
    let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick))
    link.add(to: .main, forMode: .common)
    self.displayLink = link
    self.displayLinkProxy = proxy
  }

  private func stopProgressTimer() {
    self.displayLink?.invalidate()
    self.displayLink = nil
    self.displayLinkProxy = nil
  }

  private func configureAudioSessionForPlayback() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    try? session.setActive(true)
  }

  private func handlePlaybackFinished() {
    self.isPlaying = false
    self.currentTime = 0
    self.duration = 0
    self.currentFileURL = nil
    self.stopProgressTimer()
  }
}

// MARK: - DisplayLinkProxy

private final class DisplayLinkProxy: NSObject {

  // MARK: Lifecycle

  init(onTick: @escaping @Sendable @MainActor () -> Void) {
    self.onTick = onTick
  }

  // MARK: Internal

  @objc
  func tick(_: CADisplayLink) {
    let callback = self.onTick
    MainActor.assumeIsolated {
      callback()
    }
  }

  // MARK: Private

  private let onTick: @Sendable @MainActor () -> Void
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
