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
    .listRowBackground(Self.rowTint)
  }

  // MARK: Private

  private static let rowPadding: CGFloat = 16
  private static let collapsedLineLimit = 4
  private static let toggleInterval: TimeInterval = 3
  private static let chevronSize: CGFloat = 12
  private static let pillTrailingPad: CGFloat = 10

  /// Grouped Form page background. A translucent `.listRowBackground` lets this
  /// show through, so it — not `systemBackground` — is what sits behind the row.
  private static let pageBackground = Color(.systemGroupedBackground)
  /// Row tint. Shared with `fadeOverlay` so the collapse fade dissolves into the
  /// exact background the row shows and leaves no seam.
  private static let rowTint = Color.orange.opacity(0.08)

  /// Baseline offset that vertically centers the pill on the body text line.
  /// Derived from font metrics: (ascender + descender - pillHeight) / 2.
  private static let pillBaselineOffset: CGFloat = {
    let bodyFont = UIFont.preferredFont(forTextStyle: .body)
    let pillFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
    let pillHeight = pillFont.lineHeight + 2 * 5 // pillPaddingV
    return (bodyFont.ascender + bodyFont.descender - pillHeight) / 2
  }()

  // swiftlint:disable:next line_length
  private static let infoText: LocalizedStringKey = "\u{2014} if you spot this orange indicator in the corner, there\u{2019}s nothing to worry about. It simply means Sayboard is keeping the microphone session ready, so the keyboard can start dictation the instant you want it. Nothing is recorded in the background \u{2014} the microphone only turns on when you press the record button. Whatever you say stays on your device and never leaves it. Sayboard\u{2019}s code is open \u{2014} if you like, you can go through it yourself and see first-hand that this is true.\n\nWhen you tap record, you\u{2019}ll see the app open for a moment. The system doesn\u{2019}t allow keyboards to use the microphone directly, so Sayboard briefly opens to turn it on and brings you right back. Prefer to see that less often? Increase the \u{201C}Auto-Stop\u{201D} time \u{2014} the lower it is, the more often you\u{2019}ll be switched back and forth.\n\nThe convenience of instant dictation does come at a small battery cost \u{2014} usually up to about 15% of your charge over a full day."

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
      // Dissolve into the row's own background — the page color with the row
      // tint over it — so the fade blends instead of banding to systemBackground.
      ZStack {
        Self.pageBackground
        Self.rowTint
      }
      .mask(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0.5),
            .init(color: .black, location: 1.0),
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
