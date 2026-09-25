
import SwiftUI
import UIKit

struct KeyboardPhonePreview: View {

  let kind: KeyboardKind

  var body: some View {
    Color.clear
      .frame(minWidth: 0, maxWidth: .infinity)
      .frame(height: Self.nativeSize.height * self.scale)
      .overlay(alignment: .topLeading) {
        self.phone
          .frame(width: Self.nativeSize.width, height: Self.nativeSize.height)
          .scaleEffect(self.scale, anchor: .topLeading)
      }
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { self.width = $0 }
      .accessibilityHidden(true)
  }

  private static let bezel: CGFloat = 12
  private static let screenCornerRadius: CGFloat = 47
  private static let topScreenHeight: CGFloat = 40
  private static let homeIndicatorAreaHeight: CGFloat = 48
  private static let homeIndicatorBottomInset: CGFloat = 14.5
  private static let homeIndicatorSize = CGSize(width: 134, height: 5)
  private static let extendedKeyboard = KeyboardLayoutPreview.size(for: .extended)
  private static let screenHeight = topScreenHeight + extendedKeyboard.height + homeIndicatorAreaHeight
  private static let nativeSize = CGSize(width: extendedKeyboard.width + 2 * bezel, height: screenHeight + bezel)

  private static let bezelColor = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(white: 0.32, alpha: 1)
      : UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1)
  })

  @State private var width: CGFloat = 0

  private var scale: CGFloat {
    self.width / Self.nativeSize.width
  }

  private var phone: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      VStack(spacing: 0) {
        KeyboardLayoutPreview(kind: self.kind)
        Capsule()
          .fill(Color(.label))
          .frame(width: Self.homeIndicatorSize.width, height: Self.homeIndicatorSize.height)
          .frame(maxWidth: .infinity)
          .padding(.bottom, Self.homeIndicatorBottomInset)
          .frame(height: Self.homeIndicatorAreaHeight, alignment: .bottom)
      }
      .background(KeyboardLayoutPreview.backdrop)
    }
    .frame(height: Self.screenHeight)
    .frame(maxWidth: .infinity)
    .background(Color(.systemBackground))
    .clipShape(UnevenRoundedRectangle(
      bottomLeadingRadius: Self.screenCornerRadius,
      bottomTrailingRadius: Self.screenCornerRadius,
      style: .continuous,
    ))
    .padding([.horizontal, .bottom], Self.bezel)
    .background(
      Self.bezelColor,
      in: UnevenRoundedRectangle(
        bottomLeadingRadius: Self.screenCornerRadius + Self.bezel,
        bottomTrailingRadius: Self.screenCornerRadius + Self.bezel,
        style: .continuous,
      ),
    )
  }
}
