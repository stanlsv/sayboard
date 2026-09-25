
import SwiftUI

struct MicrophonePromptTutorialView: View {

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 4) {
        Text("“\(Self.appName)” would like to access the Microphone.")
          .font(.headline)
        Text(LocalizedStringKey("NSMicrophoneUsageDescription"), tableName: "InfoPlist")
          .font(.footnote)
      }
      .multilineTextAlignment(.center)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, Self.contentPadding)
      .padding(.top, Self.titleTopPadding)
      .padding(.bottom, Self.contentPadding)
      HStack(spacing: Self.buttonSpacing) {
        self.button("Don’t Allow", isHighlighted: false)
        self.button("Allow", isHighlighted: self.isAllowHighlighted)
          .reportCenter(coordinateSpace: Self.coordinateSpace)
      }
      .padding(.horizontal, Self.contentPadding)
      .padding(.bottom, Self.contentPadding)
    }
    .background(
      Color(.secondarySystemGroupedBackground),
      in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous),
    )
    .frame(maxWidth: Self.maxWidth)
    .scaleEffect(self.isPromptShown ? 1 : Self.hiddenScale)
    .opacity(self.isPromptShown ? 1 : 0)
    .padding(.horizontal, 32)
    .coordinateSpace(name: Self.coordinateSpace)
    .onPreferenceChange(AllowCenterPreferenceKey.self) { self.allowCenter = $0 }
    .overlay {
      TutorialCursor(position: self.cursorPosition, isVisible: self.cursorVisible, isPressed: self.cursorPressed)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task {
      await self.runAnimationLoop()
    }
  }

  private static let coordinateSpace = "microphonePrompt"
  private static let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Sayboard"

  private static let maxWidth: CGFloat = 300
  private static let cornerRadius: CGFloat = 28
  private static let contentPadding: CGFloat = 16
  private static let titleTopPadding: CGFloat = 20
  private static let buttonSpacing: CGFloat = 8
  private static let buttonHeight: CGFloat = 44
  private static let hiddenScale: CGFloat = 1.08
  private static let cursorStartOffset = CGSize(width: -40, height: 90)

  private static let firstAppearDelay: UInt64 = 300_000_000
  private static let firstCursorDelay: UInt64 = 400_000_000

  private static let initialDelay: UInt64 = 800_000_000
  private static let cursorTravelDuration = 0.4
  private static let prePressPause: UInt64 = 200_000_000
  private static let pressDuration: UInt64 = 150_000_000
  private static let postPressPause: UInt64 = 300_000_000
  private static let hiddenPause: UInt64 = 600_000_000

  @State private var isPromptShown = false
  @State private var isAllowHighlighted = false
  @State private var allowCenter: CGPoint?
  @State private var cursorPosition = CGPoint.zero
  @State private var cursorVisible = false
  @State private var cursorPressed = false

  private func button(_ title: LocalizedStringKey, isHighlighted: Bool) -> some View {
    Text(title)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .frame(maxWidth: .infinity, minHeight: Self.buttonHeight)
      .background(Color(isHighlighted ? .systemGray4 : .tertiarySystemFill), in: Capsule())
  }

  private func runAnimationLoop() async {
    try? await Task.sleep(nanoseconds: Self.firstAppearDelay)
    withAnimation(.easeOut(duration: 0.25)) {
      self.isPromptShown = true
    }
    var cursorDelay = Self.firstCursorDelay
    while !Task.isCancelled {
      try? await Task.sleep(nanoseconds: cursorDelay)
      cursorDelay = Self.initialDelay

      guard let target = self.allowCenter else { continue }
      self.cursorPosition = CGPoint(x: target.x + Self.cursorStartOffset.width, y: target.y + Self.cursorStartOffset.height)
      withAnimation(.easeIn(duration: 0.15)) {
        self.cursorVisible = true
      }
      withAnimation(.easeInOut(duration: Self.cursorTravelDuration)) {
        self.cursorPosition = target
      }
      try? await Task.sleep(nanoseconds: UInt64(Self.cursorTravelDuration * 1_000_000_000))

      try? await Task.sleep(nanoseconds: Self.prePressPause)
      self.cursorPressed = true
      try? await Task.sleep(nanoseconds: Self.pressDuration)
      self.cursorPressed = false
      withAnimation(.easeInOut(duration: 0.1)) {
        self.isAllowHighlighted = true
      }
      try? await Task.sleep(nanoseconds: Self.postPressPause)

      withAnimation(.easeIn(duration: 0.2)) {
        self.isPromptShown = false
        self.cursorVisible = false
      }
      try? await Task.sleep(nanoseconds: Self.hiddenPause)
      self.isAllowHighlighted = false
      withAnimation(.easeOut(duration: 0.25)) {
        self.isPromptShown = true
      }
    }
  }
}

private struct AllowCenterPreferenceKey: PreferenceKey {
  static let defaultValue: CGPoint? = nil

  static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) {
    value = nextValue() ?? value
  }
}

extension View {
  fileprivate func reportCenter(coordinateSpace: String) -> some View {
    self.background(
      GeometryReader { geo in
        Color.clear.preference(
          key: AllowCenterPreferenceKey.self,
          value: CGPoint(
            x: geo.frame(in: .named(coordinateSpace)).midX,
            y: geo.frame(in: .named(coordinateSpace)).midY,
          ),
        )
      }
    )
  }
}
