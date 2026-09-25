
import SwiftUI
import UIKit

struct KeyboardSwitchTutorialView: View {

  var body: some View {
    Color.clear
      .frame(maxWidth: .infinity, minHeight: Self.minHeight, maxHeight: .infinity)
      .overlay {
        GeometryReader { proxy in
          self.canvas
            .frame(width: Self.width, height: self.canvasHeight)
            .scaleEffect(min(proxy.size.width / Self.width, proxy.size.height / self.canvasHeight))
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
      }
      .padding(.horizontal, Self.horizontalPadding)
      .allowsHitTesting(false)
      .accessibilityHidden(true)
      .task {
        await self.runAnimationLoop()
      }
  }

  private static let width = KeyboardLayoutPreview.size(for: .standard).width
  private static let minHeight: CGFloat = 160
  private static let horizontalPadding: CGFloat = 32
  private static let cornerRadius: CGFloat = 24
  private static let cardTopInset: CGFloat = 12
  private static let keysTopPadding: CGFloat = 8
  private static let keyHeight: CGFloat = 42
  private static let letterKeyWidth: CGFloat = 33
  private static let keySpacing: CGFloat = 6
  private static let rowSpacing: CGFloat = 12
  private static let edgeInset: CGFloat = 3
  private static let keyRadius: CGFloat = 8.5
  private static let shiftKeyWidth: CGFloat = 42
  private static let modeKeyWidth: CGFloat = 44
  private static let returnKeyWidth: CGFloat = 88
  private static let letterSize: CGFloat = 22
  private static let symbolSize: CGFloat = 18
  private static let systemKeysHeight = keysTopPadding + 4 * keyHeight + 3 * rowSpacing + keysTopPadding
  private static let topLetters = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
  private static let middleLetters = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
  private static let bottomLetters = ["z", "x", "c", "v", "b", "n", "m"]

  private static let stripHeight: CGFloat = 56
  private static let stripInset: CGFloat = 14
  private static let stripButtonSize: CGFloat = 44
  private static let stripIconSize: CGFloat = 24

  private static let menuWidth: CGFloat = 240
  private static let menuRowHeight: CGFloat = 48
  private static let menuRowInset: CGFloat = 18
  private static let menuVerticalPadding: CGFloat = 6
  private static let menuCornerRadius: CGFloat = 18
  private static let menuFontSize: CGFloat = 17
  private static let menuLeading: CGFloat = 12
  private static let menuBottomInset: CGFloat = 62
  private static let hiddenMenuScale: CGFloat = 0.8
  private static let nonLanguageModes: Set = ["emoji", "dictation", "mis"]

  private static let cursorSize: CGFloat = 48
  private static let cursorStartOffset = CGSize(width: 90, height: -80)

  private static let firstCursorDelay = Duration.milliseconds(400)
  private static let cycleDelay = Duration.milliseconds(800)
  private static let cursorTravelDuration = 0.4
  private static let prePressPause = Duration.milliseconds(200)
  private static let tapDuration = Duration.milliseconds(150)
  private static let holdBeforeMenu = Duration.milliseconds(500)
  private static let menuPause = Duration.milliseconds(400)
  private static let postTapPause = Duration.milliseconds(250)
  private static let switchDuration = 0.3
  private static let holdDelay = Duration.milliseconds(1600)

  @Environment(\.locale) private var locale
  @State private var isGlobePressed = false
  @State private var isMenuShown = false
  @State private var isSayboardRowHighlighted = false
  @State private var isSayboardShown = false
  @State private var cursorPosition = CGPoint.zero
  @State private var cursorVisible = false
  @State private var cursorPressed = false

  private let kind = SharedSettings().keyboardKind

  private var sayboardKeysHeight: CGFloat {
    KeyboardLayoutPreview.size(for: self.kind).height
  }

  private var canvasHeight: CGFloat {
    Self.cardTopInset + max(Self.systemKeysHeight, self.sayboardKeysHeight) + Self.stripHeight
  }

  private var globeCenter: CGPoint {
    CGPoint(
      x: Self.stripInset + Self.stripButtonSize / 2,
      y: self.canvasHeight - Self.stripHeight + Self.stripButtonSize / 2,
    )
  }

  private var sayboardRowCenter: CGPoint {
    CGPoint(
      x: Self.menuLeading + Self.menuWidth / 2,
      y: self.canvasHeight - Self.menuBottomInset - Self.menuVerticalPadding - Self.menuRowHeight / 2,
    )
  }

  private var systemKeyboardName: String {
    let code = UITextInputMode.activeInputModes.lazy
      .compactMap(\.primaryLanguage)
      .first { !Self.nonLanguageModes.contains($0) }
    let language = code.map { Locale(identifier: $0).language } ?? self.locale.language
    let languageCode = language.languageCode?.identifier ?? "en"
    return self.locale.capitalizedLanguageName(forLanguageCode: languageCode)
  }

  private var canvas: some View {
    ZStack(alignment: .bottomLeading) {
      self.keyboard
      self.menu
        .scaleEffect(self.isMenuShown ? 1 : Self.hiddenMenuScale, anchor: .bottomLeading)
        .opacity(self.isMenuShown ? 1 : 0)
        .offset(x: Self.menuLeading, y: -Self.menuBottomInset)
      TutorialCursor(
        position: self.cursorPosition,
        isVisible: self.cursorVisible,
        isPressed: self.cursorPressed,
        size: Self.cursorSize,
      )
    }
  }

  private var keyboard: some View {
    VStack(spacing: 0) {
      ZStack(alignment: .bottom) {
        self.systemKeys
          .opacity(self.isSayboardShown ? 0 : 1)
        KeyboardLayoutPreview(kind: self.kind)
          .opacity(self.isSayboardShown ? 1 : 0)
      }
      .frame(height: self.isSayboardShown ? self.sayboardKeysHeight : Self.systemKeysHeight, alignment: .bottom)
      .clipped()
      self.bottomStrip
    }
    .padding(.top, Self.cardTopInset)
    .background(KeyboardLayoutPreview.backdrop)
    .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    .frame(maxHeight: .infinity, alignment: .bottom)
  }

  private var systemKeys: some View {
    VStack(spacing: Self.rowSpacing) {
      self.letterRow(Self.topLetters)
      self.letterRow(Self.middleLetters)
      HStack(spacing: 0) {
        self.functionKey(Image(systemName: "shift"), width: Self.shiftKeyWidth)
        Spacer(minLength: 0)
        self.letterRow(Self.bottomLetters)
        Spacer(minLength: 0)
        self.functionKey(Image(systemName: "delete.left"), width: Self.shiftKeyWidth)
      }
      HStack(spacing: Self.keySpacing) {
        self.functionKey(Text(verbatim: "123"), width: Self.modeKeyWidth)
        self.functionKey(Image(systemName: "face.smiling"), width: Self.modeKeyWidth)
        RoundedRectangle(cornerRadius: Self.keyRadius, style: .continuous)
          .fill(KeyboardLayoutPreview.keyFill)
          .frame(height: Self.keyHeight)
        self.functionKey(Image(systemName: "return.left"), width: Self.returnKeyWidth)
      }
    }
    .padding(.horizontal, Self.edgeInset)
    .padding(.top, Self.keysTopPadding)
    .frame(width: Self.width, height: Self.systemKeysHeight, alignment: .top)
    .background(KeyboardLayoutPreview.backdrop)
  }

  private var bottomStrip: some View {
    HStack(spacing: 0) {
      Image(systemName: "globe")
        .font(.system(size: Self.stripIconSize))
        .frame(width: Self.stripButtonSize, height: Self.stripButtonSize)
        .background(Color(.systemGray3).opacity(self.isGlobePressed ? 1 : 0), in: Circle())
      Spacer(minLength: 0)
      Image(systemName: "mic")
        .font(.system(size: Self.stripIconSize))
        .frame(width: Self.stripButtonSize, height: Self.stripButtonSize)
        .opacity(self.isSayboardShown ? 0 : 1)
    }
    .padding(.horizontal, Self.stripInset)
    .frame(height: Self.stripHeight, alignment: .top)
  }

  private var menu: some View {
    VStack(spacing: 0) {
      self.menuRow(Text(verbatim: self.systemKeyboardName), isHighlighted: false)
      Divider()
        .padding(.leading, Self.menuRowInset)
      self.menuRow(Text("Sayboard"), isHighlighted: self.isSayboardRowHighlighted)
    }
    .padding(.vertical, Self.menuVerticalPadding)
    .frame(width: Self.menuWidth)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: Self.menuCornerRadius, style: .continuous))
    .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
  }

  private func letterRow(_ letters: [String]) -> some View {
    HStack(spacing: Self.keySpacing) {
      ForEach(letters, id: \.self) { letter in
        Text(verbatim: letter)
          .font(.system(size: Self.letterSize))
          .frame(width: Self.letterKeyWidth, height: Self.keyHeight)
          .background(
            KeyboardLayoutPreview.keyFill,
            in: RoundedRectangle(cornerRadius: Self.keyRadius, style: .continuous),
          )
      }
    }
  }

  private func functionKey(_ label: some View, width: CGFloat) -> some View {
    label
      .font(.system(size: Self.symbolSize))
      .frame(width: width, height: Self.keyHeight)
      .background(
        KeyboardLayoutPreview.keyFill,
        in: RoundedRectangle(cornerRadius: Self.keyRadius, style: .continuous),
      )
  }

  private func menuRow(_ title: Text, isHighlighted: Bool) -> some View {
    title
      .font(.system(size: Self.menuFontSize))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, Self.menuRowInset)
      .frame(height: Self.menuRowHeight)
      .background(isHighlighted ? Color(.systemGray4) : .clear)
  }

  private func runAnimationLoop() async {
    var startDelay = Self.firstCursorDelay
    while !Task.isCancelled {
      try? await Task.sleep(for: startDelay)
      startDelay = Self.cycleDelay

      let globe = self.globeCenter
      self.cursorPosition = CGPoint(x: globe.x + Self.cursorStartOffset.width, y: globe.y + Self.cursorStartOffset.height)
      withAnimation(.easeIn(duration: 0.15)) {
        self.cursorVisible = true
      }
      await self.moveCursor(to: globe)

      try? await Task.sleep(for: Self.prePressPause)
      self.cursorPressed = true
      self.isGlobePressed = true
      try? await Task.sleep(for: Self.holdBeforeMenu)
      withAnimation(.spring(duration: 0.25)) {
        self.isMenuShown = true
      }
      try? await Task.sleep(for: Self.menuPause)
      self.cursorPressed = false
      self.isGlobePressed = false

      await self.moveCursor(to: self.sayboardRowCenter)
      try? await Task.sleep(for: Self.prePressPause)
      self.cursorPressed = true
      try? await Task.sleep(for: Self.tapDuration)
      self.cursorPressed = false
      withAnimation(.easeInOut(duration: 0.1)) {
        self.isSayboardRowHighlighted = true
      }
      try? await Task.sleep(for: Self.postTapPause)

      withAnimation(.easeInOut(duration: Self.switchDuration)) {
        self.isMenuShown = false
        self.isSayboardShown = true
        self.cursorVisible = false
      }
      try? await Task.sleep(for: Self.holdDelay)
      self.isSayboardRowHighlighted = false
      withAnimation(.easeInOut(duration: Self.switchDuration)) {
        self.isSayboardShown = false
      }
    }
  }

  private func moveCursor(to target: CGPoint) async {
    withAnimation(.easeInOut(duration: Self.cursorTravelDuration)) {
      self.cursorPosition = target
    }
    try? await Task.sleep(for: .seconds(Self.cursorTravelDuration))
  }
}
