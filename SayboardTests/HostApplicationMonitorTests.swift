import Foundation
import Testing
@testable import Sayboard

@Suite("Finding the keyboard arbitration callback")
struct HostApplicationMonitorTests {

  @Test
  func `finding the callback does not switch the process preferences to direct mode`() throws {
    try #require(dlopen(Self.pdfKitPath, RTLD_NOW) != nil)
    try #require(objc_lookUpClass(Self.preferencesSwitchingClassName) != nil)
    let directMode = try #require(Self.preferencesDirectMode())

    _ = HostApplicationMonitor.arbitrationMethods()

    #expect(!directMode())
  }

  private typealias DirectModeFn = @convention(c) () -> UInt8

  private static let pdfKitPath = "/System/Library/Frameworks/PDFKit.framework/PDFKit"
  private static let preferencesSwitchingClassName = "PDFExtensionContext"
  private static let coreFoundationPath = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"

  private static func preferencesDirectMode() -> (() -> Bool)? {
    guard
      let coreFoundation = dlopen(self.coreFoundationPath, RTLD_NOW),
      let symbol = dlsym(coreFoundation, "_CFPrefsDirectMode")
    else { return nil }
    let function = unsafeBitCast(symbol, to: DirectModeFn.self)
    return { function() != 0 }
  }
}
