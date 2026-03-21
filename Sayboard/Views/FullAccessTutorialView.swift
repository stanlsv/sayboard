// FullAccessTutorialView -- Animated mock of iOS Settings guiding the user to enable Full Access.

import SwiftUI

// MARK: - FullAccessTutorialView

struct FullAccessTutorialView: View {

  // MARK: Internal

  var includeFullAccessRow = true

  var body: some View {
    VStack(spacing: 0) {
      self.keyboardsRow

      if self.showToggleRows {
        Divider()
          .padding(.leading, 16)

        self.toggleRow(
          title: "Sayboard",
          isOn: self.sayboardToggleOn,
          id: RowID.sayboardToggle,
        )

        if self.includeFullAccessRow {
          Divider()
            .padding(.leading, 16)

          self.toggleRow(
            title: "Allow Full Access",
            isOn: self.fullAccessToggleOn,
            id: RowID.fullAccessToggle,
          )
        }
      }
    }
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .padding(.horizontal, 32)
    .coordinateSpace(name: Self.coordinateSpace)
    .onPreferenceChange(RowCenterPreferenceKey.self) { centers in
      self.rowCenters = centers
    }
    .overlay {
      self.cursorCircle
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .task {
      await self.runAnimationLoop()
    }
  }

  // MARK: Fileprivate

  fileprivate enum RowID: String {
    case keyboards
    case sayboardToggle
    case fullAccessToggle
  }

  // MARK: Private

  private static let coordinateSpace = "tutorial"

  // Timing constants (nanoseconds)
  private static let initialDelay: UInt64 = 800_000_000
  private static let cursorTravelDuration = 0.4
  private static let prePressPause: UInt64 = 200_000_000
  private static let pressDuration: UInt64 = 150_000_000
  private static let postPressPause: UInt64 = 300_000_000
  private static let toggleFlipPause: UInt64 = 800_000_000
  private static let holdDelay: UInt64 = 1_500_000_000
  private static let resetDelay: UInt64 = 400_000_000

  private static let cursorSize: CGFloat = 36
  private static let cursorPressedScale: CGFloat = 0.75

  @State private var showToggleRows = false
  @State private var sayboardToggleOn = false
  @State private var fullAccessToggleOn = false
  @State private var isKeyboardsHighlighted = false

  @State private var cursorPosition = CGPoint.zero
  @State private var cursorVisible = false
  @State private var cursorPressed = false
  @State private var rowCenters = [String: CGPoint]()

  private var keyboardsRow: some View {
    HStack {
      Text("Keyboards")
        .foregroundStyle(.primary)

      Spacer()

      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(self.isKeyboardsHighlighted ? Color(.systemGray4) : .clear)
    .reportCenter(id: .keyboards, coordinateSpace: Self.coordinateSpace)
  }

  private var cursorCircle: some View {
    Circle()
      .fill(Color.primary.opacity(self.cursorPressed ? 0.45 : 0.25))
      .frame(width: Self.cursorSize, height: Self.cursorSize)
      .scaleEffect(self.cursorPressed ? Self.cursorPressedScale : 1.0)
      .shadow(color: .primary.opacity(0.1), radius: 4)
      .position(self.cursorPosition)
      .opacity(self.cursorVisible ? 1 : 0)
      .animation(.easeOut(duration: 0.08), value: self.cursorPressed)
  }

  private func toggleRow(title: LocalizedStringKey, isOn: Bool, id: RowID) -> some View {
    HStack {
      Text(title)
        .foregroundStyle(.primary)

      Spacer()

      Toggle(isOn: .constant(isOn)) {
        EmptyView()
      }
      .labelsHidden()
      .reportCenter(id: id, coordinateSpace: Self.coordinateSpace)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .transition(.move(edge: .top).combined(with: .opacity))
  }

  private func runAnimationLoop() async {
    while !Task.isCancelled {
      try? await Task.sleep(nanoseconds: Self.initialDelay)

      // Show cursor and move to keyboards row
      self.cursorVisible = true
      await self.moveCursor(to: .keyboards)

      // Press on keyboards row
      try? await Task.sleep(nanoseconds: Self.prePressPause)
      await self.performPress()

      withAnimation(.easeInOut(duration: 0.1)) {
        self.isKeyboardsHighlighted = true
      }
      try? await Task.sleep(nanoseconds: Self.postPressPause)
      withAnimation(.easeInOut(duration: 0.15)) {
        self.isKeyboardsHighlighted = false
      }

      // Show toggle rows
      withAnimation(.easeOut(duration: 0.3)) {
        self.showToggleRows = true
      }

      // Wait for layout to settle so toggle row positions are captured
      try? await Task.sleep(nanoseconds: Self.toggleFlipPause)

      // Move to Sayboard toggle, press, flip
      await self.moveCursor(to: .sayboardToggle)
      try? await Task.sleep(nanoseconds: Self.prePressPause)
      await self.performPress()
      withAnimation(.easeInOut(duration: 0.25)) {
        self.sayboardToggleOn = true
      }

      // Move to Allow Full Access toggle, press, flip
      if self.includeFullAccessRow {
        try? await Task.sleep(nanoseconds: Self.toggleFlipPause)
        await self.moveCursor(to: .fullAccessToggle)
        try? await Task.sleep(nanoseconds: Self.prePressPause)
        await self.performPress()
        withAnimation(.easeInOut(duration: 0.25)) {
          self.fullAccessToggleOn = true
        }
      }

      // Hold
      try? await Task.sleep(nanoseconds: Self.holdDelay)

      // Fade out cursor, then reset card
      withAnimation(.easeIn(duration: 0.2)) {
        self.cursorVisible = false
      }
      try? await Task.sleep(nanoseconds: Self.resetDelay)

      withAnimation(.easeIn(duration: 0.2)) {
        self.showToggleRows = false
        self.sayboardToggleOn = false
        self.fullAccessToggleOn = false
      }
      try? await Task.sleep(nanoseconds: Self.resetDelay)
    }
  }

  private func moveCursor(to row: RowID) async {
    guard let target = self.rowCenters[row.rawValue] else { return }
    withAnimation(.easeInOut(duration: Self.cursorTravelDuration)) {
      self.cursorPosition = target
    }
    try? await Task.sleep(nanoseconds: UInt64(Self.cursorTravelDuration * 1_000_000_000))
  }

  private func performPress() async {
    self.cursorPressed = true
    try? await Task.sleep(nanoseconds: Self.pressDuration)
    self.cursorPressed = false
  }
}

// MARK: - RowCenterPreferenceKey

private struct RowCenterPreferenceKey: PreferenceKey {
  static let defaultValue = [String: CGPoint]()

  static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) {
    value.merge(nextValue()) { _, new in new }
  }
}

// MARK: - ReportCenter Modifier

extension View {
  fileprivate func reportCenter(
    id: FullAccessTutorialView.RowID,
    coordinateSpace: String,
  ) -> some View {
    self.background(
      GeometryReader { geo in
        Color.clear.preference(
          key: RowCenterPreferenceKey.self,
          value: [id.rawValue: CGPoint(
            x: geo.frame(in: .named(coordinateSpace)).midX,
            y: geo.frame(in: .named(coordinateSpace)).midY,
          )],
        )
      }
    )
  }
}
