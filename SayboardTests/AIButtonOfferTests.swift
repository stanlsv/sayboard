import Foundation
import Testing
@testable import Sayboard

@Suite("The History card that offers the AI button once")
struct AIButtonOfferTests {

  @Test
  func `the offer is due without any dictation`() {
    #expect(Self.isDue())
  }

  @Test
  func `a closed offer never comes back`() {
    #expect(!Self.isDue(isClosed: true))
  }

  @Test
  func `no offer where the model cannot run`() {
    #expect(!Self.isDue(canRunModel: false))
  }

  @Test
  func `no offer once a text model is on the phone`() {
    #expect(!Self.isDue(hasTextModel: true))
  }

  @Test
  func `no offer while dictation is locked`() {
    #expect(!Self.isDue(isDictationLocked: true))
  }

  private static func isDue(
    isClosed: Bool = false,
    canRunModel: Bool = true,
    hasTextModel: Bool = false,
    isDictationLocked: Bool = false,
  ) -> Bool {
    AIButtonOffer.isDue(
      isClosed: isClosed,
      canRunModel: canRunModel,
      hasTextModel: hasTextModel,
      isDictationLocked: isDictationLocked,
    )
  }

}
