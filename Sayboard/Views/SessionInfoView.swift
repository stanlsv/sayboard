import SwiftUI

// MARK: - PillContent

/// Static pill view rendered to a UIImage via ImageRenderer for inline display in Text.
private struct PillContent: View {

  // MARK: Internal

  let showingMic: Bool
  let timeString: String

  var body: some View {
    Text(self.timeString)
      .font(Self.pillFont)
      .hidden()
      .overlay {
        if self.showingMic {
          Image(systemName: "mic.fill")
            .font(.system(size: Self.pillIconSize, weight: .semibold))
        } else {
          Text(self.timeString)
            .font(Self.pillFont)
        }
      }
      .foregroundStyle(.white)
      .padding(.horizontal, Self.pillPaddingH)
      .padding(.vertical, Self.pillPaddingV)
      .background(Color.orange, in: Capsule())
  }

  // MARK: Private

  private static let pillFont = Font.system(size: 10, weight: .semibold)
  private static let pillIconSize: CGFloat = 10
  private static let pillPaddingH: CGFloat = 11
  private static let pillPaddingV: CGFloat = 5
}

// MARK: - SessionInfoView

/// Expandable info block explaining the orange mic indicator, app-switching, and battery impact.
/// Rendered as a standard Form row with orange-tinted background.
struct SessionInfoView: View {

  // MARK: Internal

  var body: some View {
    Section {
      self.expandableText
        .listRowInsets(EdgeInsets())
    }
    .listRowBackground(Color.orange.opacity(0.08))
  }

  // MARK: Private

  private static let rowPadding: CGFloat = 16
  private static let collapsedLineLimit = 4
  private static let toggleInterval: TimeInterval = 3
  private static let chevronSize: CGFloat = 12
  private static let pillTrailingPad: CGFloat = 10

  /// Baseline offset that vertically centers the pill on the body text line.
  /// Derived from font metrics: (ascender + descender - pillHeight) / 2.
  private static let pillBaselineOffset: CGFloat = {
    let bodyFont = UIFont.preferredFont(forTextStyle: .body)
    let pillFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
    let pillHeight = pillFont.lineHeight + 2 * 5 // pillPaddingV
    return (bodyFont.ascender + bodyFont.descender - pillHeight) / 2
  }()

  // swiftlint:disable:next line_length
  private static let infoText: LocalizedStringKey = "\u{2014} if you see this orange indicator in the corner of the screen, don\u{2019}t worry. It means Sayboard is keeping the microphone session ready so the keyboard can start dictation instantly. No hidden recording is happening \u{2014} the microphone only activates when you press the record button. As a reminder, your voice is processed locally on your iPhone and never leaves your device.\n\nSwitching to the app when you tap the record button is a necessary measure. iOS does not allow keyboard extensions to access the microphone directly, so Sayboard briefly opens to activate it and immediately returns you back. To see these transitions less often, increase the time in the \u{201C}Auto-Stop\u{201D} setting.\n\nBattery usage while the orange indicator is on is minimal over a full day of an active session. However, you can reduce the time in the \u{201C}Auto-Stop\u{201D} setting, but keep in mind: the lower the value, the more often the app will switch you back and forth to activate the microphone."

  @Environment(\.displayScale) private var displayScale

  @State private var isExpanded = false
  @State private var showingMic = true
  @State private var pillImage: Image?

  private let timer = Timer
    .publish(every: Self.toggleInterval, on: .main, in: .common)
    .autoconnect()

  private var composedText: Text {
    if let image = self.pillImage {
      Text(image).baselineOffset(Self.pillBaselineOffset) + Text(Self.infoText)
    } else {
      Text(Self.infoText)
    }
  }

  private var chevron: some View {
    Image(systemName: "chevron.down")
      .font(.system(size: Self.chevronSize, weight: .semibold))
      .foregroundStyle(.primary)
      .rotationEffect(.degrees(self.isExpanded ? 180 : 0))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .padding(.horizontal, Self.rowPadding)
  }

  @ViewBuilder
  private var fadeOverlay: some View {
    if !self.isExpanded {
      Color(.systemBackground)
        .mask(
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0.65),
              .init(color: .black.opacity(0.85), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom,
          )
        )
        .allowsHitTesting(false)
    }
  }

  private var expandableText: some View {
    VStack(spacing: 0) {
      self.composedText
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(self.isExpanded ? nil : Self.collapsedLineLimit)
        .onAppear { self.renderPill() }
        .onReceive(self.timer) { _ in
          self.showingMic.toggle()
          self.renderPill()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.rowPadding)
        .overlay { self.fadeOverlay }
        .overlay(alignment: .bottom) {
          if !self.isExpanded { self.chevron }
        }

      if self.isExpanded { self.chevron }
    }
    .contentShape(Rectangle())
    .onTapGesture {
      self.isExpanded.toggle()
    }
  }

  @MainActor
  private func renderPill() {
    let timeString = Date.now.formatted(.dateTime.hour().minute())
    let content = PillContent(showingMic: self.showingMic, timeString: timeString)
      .padding(.trailing, Self.pillTrailingPad)
    let renderer = ImageRenderer(content: content)
    renderer.scale = self.displayScale
    if let uiImage = renderer.uiImage {
      self.pillImage = Image(uiImage: uiImage)
    }
  }
}
