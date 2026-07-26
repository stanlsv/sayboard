import SwiftUI

// MARK: - MicSizing

struct MicSizing {
  let buttonWidth: CGFloat
  let buttonHeight: CGFloat
  let cornerRadius: CGFloat
  let labelWidth: CGFloat
  let labelHeight: CGFloat
  let spinnerSize: CGFloat
  let waveformScale: CGFloat
  let pulseRingSpacing: CGFloat
}

extension MicSizing {
  /// Standard layout: a large circular mic (corner radius = half the size).
  @MainActor
  static var standard: MicSizing {
    MicSizing(
      buttonWidth: 106.kbScaled,
      buttonHeight: 106.kbScaled,
      cornerRadius: 53.kbScaled,
      labelWidth: 56.kbScaled,
      labelHeight: 42.kbScaled,
      spinnerSize: 42.kbScaled,
      waveformScale: 1.0,
      pulseRingSpacing: 24.kbScaled,
    )
  }

  /// Extended layout: a capsule-shaped mic — the Enter key's `width` (passed in)
  /// and height (`keyHeight`), but fully rounded ends (corner radius = height / 2)
  /// so it reads as a pill while the chrome row stays short.
  @MainActor
  static func extended(width: CGFloat) -> MicSizing {
    let micScale: CGFloat = 74.0 / 106.0
    // Inner content (icon, waveform, spinner) trimmed a further 18% so it doesn't
    // crowd the capsule; the pulse rings keep the original scale.
    let contentScale = micScale * 0.82
    return MicSizing(
      buttonWidth: width,
      buttonHeight: KeyboardChromeMetrics.keyHeight,
      cornerRadius: KeyboardChromeMetrics.keyHeight / 2,
      labelWidth: 56.kbScaled * contentScale,
      labelHeight: 42.kbScaled * contentScale,
      spinnerSize: 42.kbScaled * contentScale,
      waveformScale: contentScale,
      pulseRingSpacing: 24.kbScaled * micScale,
    )
  }
}

// MARK: - MicAnimatedButton

/// Mic button with the idle ↔ wave ↔ spinner morph state machine and dictation IPC handshake.
struct MicAnimatedButton: View {

  // MARK: Internal

  let sizing: MicSizing
  let proxy: KeyboardProxy

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    Button(action: self.handleTap) {
      self.micButtonLabel
    }
    .buttonStyle(MicButtonStyle(
      width: self.sizing.buttonWidth,
      height: self.sizing.buttonHeight,
      cornerRadius: self.sizing.cornerRadius,
    ))
    .allowsHitTesting(!self.keyboardState.isProcessing)
    .onChange(of: self.keyboardState.isRecording, self.handleRecordingChanged)
    .task(id: self.keyboardState.isProcessing, self.observeProcessing)
    .gatedSensoryFeedback(.impact(weight: .medium), trigger: self.recordingStartCount)
    .gatedSensoryFeedback(.impact(weight: .light), trigger: self.recordingStopCount)
  }

  // MARK: Private

  private static let spinnerDelay = Duration.milliseconds(600)

  @State private var showSpinner = false
  @State private var isMorphing = false
  @State private var isSpinnerMorphing = false
  @State private var spinnerMorphCanStep = false
  @State private var pendingSpinnerMorph = false
  @State private var morphDirection = MicMorphAnimation.Direction.toWave
  @State private var recordingStartCount = 0
  @State private var recordingStopCount = 0

  @ViewBuilder
  private var micButtonLabel: some View {
    let shouldShowWave = self.keyboardState.isRecording
    let isLoading = self.keyboardState.isModelLoading && !self.keyboardState.isRecording
    let isSpin = self.showSpinner || (isLoading && !self.isSpinnerMorphing && !self.pendingSpinnerMorph)
    let isIdle = !shouldShowWave && !isSpin && !self.isMorphing && !self.isSpinnerMorphing
      && !self.pendingSpinnerMorph
    ZStack {
      MicMorphShape(frameIndex: 0)
        .fill(.primary)
        .frame(width: self.sizing.labelWidth, height: self.sizing.labelHeight)
        .opacity(isIdle ? 1 : 0)
        .transaction { $0.animation = nil }

      if self.isMorphing {
        MicMorphAnimation(direction: self.morphDirection, onComplete: self.handleMicMorphComplete)
          .frame(width: self.sizing.labelWidth, height: self.sizing.labelHeight)
          .transition(.identity)
      }

      if self.isSpinnerMorphing {
        SpinnerMorphAnimation(canStep: self.spinnerMorphCanStep) {
          self.isSpinnerMorphing = false
          self.spinnerMorphCanStep = false
        }
        .frame(width: self.sizing.labelWidth, height: self.sizing.labelHeight)
        .transition(.identity)
      }

      WaveformBars(level: self.keyboardState.audioLevel, scale: self.sizing.waveformScale)
        .opacity(
          shouldShowWave && !isSpin && !self.isMorphing
            && !self.isSpinnerMorphing && !self.pendingSpinnerMorph ? 1 : 0
        )

      self.spinnerView(isSpin: isSpin)
    }
  }

  private func handleTap() {
    if self.keyboardState.isRecording {
      self.proxy.stopDictation()
    } else if self.keyboardState.isSessionActive {
      self.proxy.startDictation()
    } else if let url = DeepLink.dictateURL {
      let settings = SharedSettings()
      // Stamp timestamp BEFORE the bool: a reader observing flag=true with
      // timestamp=0 (mid-write crash) treats the request as stale, not recent.
      settings.keyboardRequestedDictationAt = CFAbsoluteTimeGetCurrent()
      settings.keyboardRequestedDictation = true
      settings.dictationSessionToken = UUID().uuidString
      settings.synchronize()
      self.proxy.openURL(url)
    }
  }

  private func handleRecordingChanged(oldValue: Bool, isRecording: Bool) {
    if isRecording, !oldValue {
      self.recordingStartCount &+= 1
    } else if !isRecording, oldValue {
      self.recordingStopCount &+= 1
    }
    if isRecording, !oldValue, !self.isMorphing {
      self.morphDirection = .toWave
      self.isMorphing = true
    } else if
      !isRecording, oldValue, !self.isMorphing, !self.showSpinner, !self.isSpinnerMorphing,
      !self.pendingSpinnerMorph
    {
      self.morphDirection = .toMic
      self.isMorphing = true
    }
  }

  private func observeProcessing() async {
    let isProcessing = self.keyboardState.isProcessing
    if isProcessing {
      do {
        try await Task.sleep(for: Self.spinnerDelay)
      } catch {
        return
      }
      self.showSpinner = true
    } else {
      if self.showSpinner {
        self.pendingSpinnerMorph = true
      }
      self.showSpinner = false
    }
  }

  private func spinnerView(isSpin: Bool) -> some View {
    MetaballSpinner(color: .primary, size: self.sizing.spinnerSize)
      .scaleEffect(isSpin ? 1 : 0.01)
      .transaction(value: isSpin) { transaction in
        transaction.animation = .easeOut(duration: 0.2)
        if !isSpin {
          transaction.addAnimationCompletion {
            if self.pendingSpinnerMorph {
              self.pendingSpinnerMorph = false
              self.isSpinnerMorphing = true
              self.spinnerMorphCanStep = true
            }
          }
        }
      }
  }

  private func handleMicMorphComplete() {
    let wantWave = self.keyboardState.isRecording
    self.isMorphing = false
    if self.morphDirection == .toWave, !wantWave {
      self.morphDirection = .toMic
      self.isMorphing = true
    } else if self.morphDirection == .toMic, wantWave {
      self.morphDirection = .toWave
      self.isMorphing = true
    }
  }
}

// MARK: - MicButtonWithPulse

struct MicButtonWithPulse: View {

  // MARK: Internal

  let sizing: MicSizing
  let proxy: KeyboardProxy
  /// Set once at construction; flipping at runtime resets the wrapped `MicAnimatedButton`'s
  /// `@State` due to changed structural identity across the two body branches.
  ///
  /// `true`: rings rendered in full (`ZStack` + `frame(minHeight:)`).
  /// `false`: rings overflow the parent and clip via `view.clipsToBounds`.
  var reservesPulseSpace = true

  @ObservedObject var keyboardState: KeyboardState

  var body: some View {
    let pulse = PulseRings(
      buttonWidth: self.sizing.buttonWidth,
      buttonHeight: self.sizing.buttonHeight,
      cornerRadius: self.sizing.cornerRadius,
      ringSpacing: self.sizing.pulseRingSpacing,
    )
    let showPulseRings = self.keyboardState.isRecording && !self.keyboardState.isProcessing
    if self.reservesPulseSpace {
      ZStack {
        self.decoratedPulse(pulse: pulse, show: showPulseRings)
        self.micButton
      }
      .frame(minHeight: pulse.maxHeight)
    } else {
      self.micButton.overlay {
        self.decoratedPulse(pulse: pulse, show: showPulseRings)
      }
    }
  }

  // MARK: Private

  private var micButton: some View {
    MicAnimatedButton(sizing: self.sizing, proxy: self.proxy, keyboardState: self.keyboardState)
  }

  private func decoratedPulse(pulse: PulseRings, show: Bool) -> some View {
    pulse
      .opacity(show ? 1 : 0)
      .scaleEffect(show ? 1 : 0.69)
      .animation(.easeOut(duration: 0.4), value: show)
      .allowsHitTesting(false)
  }
}

// MARK: - MicButtonStyle

/// Rounded-rectangle mic background — a circle when cornerRadius is half the size
/// (standard layout), a wide rounded rect when it isn't (extended layout).
struct MicButtonStyle: ButtonStyle {
  let width: CGFloat
  let height: CGFloat
  let cornerRadius: CGFloat

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(.primary)
      .frame(width: self.width, height: self.height)
      .background {
        RoundedRectangle(cornerRadius: self.cornerRadius, style: .continuous).fill(Color(.keyBackground))
      }
  }
}
