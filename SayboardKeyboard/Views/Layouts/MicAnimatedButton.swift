import SwiftUI

// MARK: - MicSizing

struct MicSizing {
  let buttonDiameter: CGFloat
  let labelWidth: CGFloat
  let labelHeight: CGFloat
  let spinnerSize: CGFloat
  let waveformScale: CGFloat
  let pulseRingSpacing: CGFloat
}

extension MicSizing {
  @MainActor
  static var standard: MicSizing {
    MicSizing(
      buttonDiameter: 106.kbScaled,
      labelWidth: 56.kbScaled,
      labelHeight: 42.kbScaled,
      spinnerSize: 42.kbScaled,
      waveformScale: 1.0,
      pulseRingSpacing: 24.kbScaled,
    )
  }

  @MainActor
  static var extended: MicSizing {
    let micScale: CGFloat = 74.0 / 106.0
    return MicSizing(
      buttonDiameter: 74.kbScaled,
      labelWidth: 56.kbScaled * micScale,
      labelHeight: 42.kbScaled * micScale,
      spinnerSize: 42.kbScaled * micScale,
      waveformScale: micScale,
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
    .buttonStyle(CircleKeyStyle(diameter: self.sizing.buttonDiameter))
    .allowsHitTesting(!self.keyboardState.isProcessing)
    .onChange(of: self.keyboardState.isRecording, self.handleRecordingChanged)
    .task(id: self.keyboardState.isProcessing, self.observeProcessing)
  }

  // MARK: Private

  private static let spinnerDelay = Duration.milliseconds(600)

  @State private var showSpinner = false
  @State private var isMorphing = false
  @State private var isSpinnerMorphing = false
  @State private var spinnerMorphCanStep = false
  @State private var pendingSpinnerMorph = false
  @State private var morphDirection = MicMorphAnimation.Direction.toWave

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
      settings.keyboardRequestedDictation = true
      settings.dictationSessionToken = UUID().uuidString
      settings.synchronize()
      self.proxy.openURL(url)
    }
  }

  private func handleRecordingChanged(oldValue: Bool, isRecording: Bool) {
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
    let pulse = PulseRings(buttonDiameter: self.sizing.buttonDiameter, ringSpacing: self.sizing.pulseRingSpacing)
    let showPulseRings = self.keyboardState.isRecording && !self.keyboardState.isProcessing
    if self.reservesPulseSpace {
      ZStack {
        self.decoratedPulse(pulse: pulse, show: showPulseRings)
        self.micButton
      }
      .frame(minHeight: pulse.maxDiameter)
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
