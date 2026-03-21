import ObjectiveC

import UIKit

// MARK: - Host Detection & URL Opening

extension KeyboardViewController {

  // MARK: Internal

  func saveHostBundleId() {
    let settings = SharedSettings()
    let hostId = self.detectHostBundleId()
    guard let hostId else {
      if let old = settings.hostBundleId, old == "<null>" || old == "nil" || old.isEmpty {
        settings.hostBundleId = nil
      } else if let old = settings.hostBundleId {
      } else { }
      settings.synchronize()
      return
    }
    settings.hostBundleId = hostId
    settings.synchronize()
  }

  func openURL(_ url: URL) {
    // Strategy 1: Responder chain
    if self.openURLViaResponderChain(url) { return }

    // Strategy 2: KVC fallback
    if self.openURLViaKVC(url) { return }
  }

  // MARK: Private

  private func detectHostBundleId() -> String? {
    guard let parent else { return nil }
    // Strategy 1: KVC on _hostBundleID (pre-iOS 16)
    if let hostId = readIvarString(from: parent, key: "_hostBundleID") {
      return hostId
    }
    // Strategy 2: PKService/XPC (iOS 16+, from KeyboardKit)
    if let hostId = detectViaPKService(parent: parent) {
      return hostId
    }
    return nil
  }

  private func detectViaPKService(parent: NSObject) -> String? {
    // Read raw _hostPID for dictionary lookup
    let parentCls: AnyClass = type(of: parent)
    guard
      class_getInstanceVariable(parentCls, "_hostPID") != nil,
      let pid = parent.value(forKey: "_hostPID")
    else {
      return nil
    }
    // Get PKService.defaultService
    let defSel = NSSelectorFromString("defaultService")
    guard
      let pkCls = NSClassFromString("PKService") as? NSObject.Type,
      pkCls.responds(to: defSel),
      let svc = pkCls.perform(defSel)?
        .takeUnretainedValue() as? NSObjectProtocol
    else {
      return nil
    }
    // Access personalities dictionary
    let pSel = NSSelectorFromString("personalities")
    guard
      svc.responds(to: pSel),
      let dict = svc.perform(pSel)?
        .takeUnretainedValue() as? NSDictionary
    else {
      return nil
    }
    let extId = Bundle.main.bundleIdentifier ?? ""
    guard
      let extDict = dict.object(forKey: extId) as? NSDictionary,
      let pidInfo = extDict.object(forKey: pid) as? NSObjectProtocol
    else {
      return nil
    }
    return self.bundleIdFromXPCConnection(of: pidInfo)
  }

  /// Extracts host bundle ID from an XPC connection on a PKService personality entry.
  private func bundleIdFromXPCConnection(of pidInfo: NSObjectProtocol) -> String? {
    let connSel = NSSelectorFromString("connection")
    let xpcSel = NSSelectorFromString("_xpcConnection")
    guard
      pidInfo.responds(to: connSel),
      let conn = pidInfo.perform(connSel)?
        .takeUnretainedValue() as? NSObjectProtocol,
      conn.responds(to: xpcSel),
      let xpcConn = conn.perform(xpcSel)?.takeUnretainedValue()
    else {
      return nil
    }
    guard
      let handle = dlopen("/usr/lib/libc.dylib", RTLD_NOW),
      let sym = dlsym(handle, "xpc_connection_copy_bundle_id")
    else {
      return nil
    }
    defer { dlclose(handle) }
    typealias BundleIdFn = @convention(c) (AnyObject) -> UnsafePointer<CChar>?
    let fn = unsafeBitCast(sym, to: BundleIdFn.self)
    guard let cStr = fn(xpcConn) else {
      return nil
    }
    defer { free(UnsafeMutablePointer(mutating: cStr)) }
    guard let result = String(utf8String: cStr), !result.isEmpty else {
      return nil
    }
    return result
  }

  private func readIvarString(from object: NSObject, key: String) -> String? {
    let cls: AnyClass = type(of: object)
    guard class_getInstanceVariable(cls, key) != nil else {
      return nil
    }
    guard let raw = object.value(forKey: key) else {
      return nil
    }
    let val = "\(raw)"
    guard !val.isEmpty, val != "<null>", val != "nil" else { return nil }
    return val
  }

  /// Open a URL from the keyboard extension.
  /// Strategy 1: Walk responder chain for openURL:options:completionHandler:
  ///             (KeyboardKit 8.8.7 approach for iOS 18+).
  /// Strategy 2: Access UIApplication.shared via KVC as fallback.
  private func openURLViaResponderChain(_ url: URL) -> Bool {
    let selector = NSSelectorFromString("openURL:options:completionHandler:")
    var responder: UIResponder? = self
    var depth = 0
    while let current = responder {
      let responds = current.responds(to: selector)

      if responds {
        if let app = current as? UIApplication {
          app.open(url, options: [:], completionHandler: nil)
          return true
        }
      }
      responder = current.next
      depth += 1
    }
    return false
  }

  private func openURLViaKVC(_ url: URL) -> Bool {
    guard
      let appClass = NSClassFromString("UIApplication"),
      let sharedSel = NSSelectorFromString("sharedApplication") as Selector?,
      appClass.responds(to: sharedSel),
      let result = (appClass as AnyObject).perform(sharedSel),
      let app = result.takeUnretainedValue() as? UIApplication
    else {
      return false
    }
    app.open(url, options: [:], completionHandler: nil)
    return true
  }
}
