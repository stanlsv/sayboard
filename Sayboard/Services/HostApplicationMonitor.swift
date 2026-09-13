
import ObjectiveC

import UIKit

enum HostApplicationMonitor {

  static func start() {
    guard !self.didStart else { return }
    self.didStart = true
    let available = self.payloadCarriesHost() && self.installArbitrationHook() > 0
    let settings = SharedSettings()
    settings.canResolveHostApplication = available
    if settings.hostBundleId == nil {
      settings.hostBundleId = self.recoveredHost()
    }
    settings.synchronize()
    DiagnosticLog.write("host monitor started, available=\(available)")
  }

  private static let ignoredHosts: Set = [
    "com.apple.springboard",
    "app.sayboard",
    "app.sayboard.keyboard",
  ]

  private static let rememberedHostTTL: TimeInterval = 12 * 60 * 60

  private static let changedSelector = NSSelectorFromString("queue_keyboardChanged:onComplete:")
  private static let sourceBundleIvar = "_sourceBundleIdentifier"

  private nonisolated(unsafe) static var didStart = false

  private static func recoveredHost() -> String? {
    guard let host = RememberedHost.matchingCurrentProcess(ttl: self.rememberedHostTTL) else {
      return nil
    }
    DiagnosticLog.write("host recovered: \(host.bundleId) pid=\(host.pid)")
    return host.bundleId
  }

  private static func payloadCarriesHost() -> Bool {
    guard let cls: AnyClass = NSClassFromString("_UIKeyboardChangedInformation") else { return false }
    return class_getInstanceVariable(cls, self.sourceBundleIvar) != nil
  }

  private static func installArbitrationHook() -> Int {
    let total = objc_getClassList(nil, 0)
    guard total > 0 else { return 0 }
    let buffer = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(total))
    defer { buffer.deallocate() }
    let written = objc_getClassList(AutoreleasingUnsafeMutablePointer<AnyClass>(buffer), total)
    var seen = Set<OpaquePointer>()
    for index in 0..<Int(written) {
      guard let method = class_getInstanceMethod(buffer[index], self.changedSelector) else { continue }
      guard seen.insert(method).inserted else { continue }
      typealias ArbitrationFn = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> Void
      let callThrough = unsafeBitCast(method_getImplementation(method), to: ArbitrationFn.self)
      let block: @convention(block) (AnyObject, AnyObject?, AnyObject?) -> Void = { receiver, info, completion in
        if let info = info as? NSObject { self.record(from: info) }
        callThrough(receiver, self.changedSelector, info, completion)
      }
      method_setImplementation(method, imp_implementationWithBlock(block))
    }
    return seen.count
  }

  private static func record(from info: NSObject) {
    guard
      let ivar = class_getInstanceVariable(type(of: info), self.sourceBundleIvar),
      let encoding = ivar_getTypeEncoding(ivar).map({ String(cString: $0) }),
      encoding.hasPrefix("@")
    else { return }
    let slot = Unmanaged.passUnretained(info).toOpaque().advanced(by: ivar_getOffset(ivar))
    guard let raw = slot.load(as: UnsafeRawPointer?.self) else { return }
    guard let bundleId = Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? NSString else {
      return
    }
    self.store(bundleId as String)
  }

  private static func store(_ bundleId: String) {
    DiagnosticLog.write("host event: \(bundleId)")
    guard !bundleId.isEmpty, !self.ignoredHosts.contains(bundleId) else { return }
    let settings = SharedSettings()
    guard settings.hostBundleId != bundleId else { return }
    settings.hostBundleId = bundleId
    RememberedHost.remember(bundleId)
    settings.synchronize()
    DiagnosticLog.write("host resolved: \(bundleId)")
  }
}
