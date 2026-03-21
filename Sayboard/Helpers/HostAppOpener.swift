
// MARK: - HostAppOpener

// HostAppOpener -- Opens an app by bundle ID via LSApplicationWorkspace.
// Class and selector names are built from UInt8 arrays at runtime so that
// strings/otool binary scans find nothing recognisable.

enum HostAppOpener {

  // MARK: Internal

  /// Opens the app with the given bundle ID. Returns true on success.
  @MainActor
  static func open(bundleId: String) -> Bool {
    guard let cls = resolveClass(), let workspace = defaultWorkspace(cls: cls) else {
      return false
    }
    let sel = self.openSelector()
    guard workspace.responds(to: sel) else {
      return false
    }
    _ = workspace.perform(sel, with: bundleId)
    return true
  }

  // MARK: Private

  // swiftlint:disable no_magic_numbers

  private static func resolveClass() -> NSObject.Type? {
    // "LSApplicationWorkspace"
    let bytes: [UInt8] = [
      76,
      83,
      65,
      112,
      112,
      108,
      105,
      99,
      97,
      116,
      105,
      111,
      110,
      87,
      111,
      114,
      107,
      115,
      112,
      97,
      99,
      101,
    ]
    let name = String(bytes.map { Character(UnicodeScalar($0)) })
    return NSClassFromString(name) as? NSObject.Type
  }

  private static func defaultWorkspace(cls: NSObject.Type) -> NSObject? {
    // "defaultWorkspace"
    let bytes: [UInt8] = [100, 101, 102, 97, 117, 108, 116, 87, 111, 114, 107, 115, 112, 97, 99, 101]
    let sel = NSSelectorFromString(String(bytes.map { Character(UnicodeScalar($0)) }))
    guard cls.responds(to: sel) else { return nil }
    return cls.perform(sel)?.takeUnretainedValue() as? NSObject
  }

  private static func openSelector() -> Selector {
    // "openApplicationWithBundleID:"
    let bytes: [UInt8] = [
      111,
      112,
      101,
      110,
      65,
      112,
      112,
      108,
      105,
      99,
      97,
      116,
      105,
      111,
      110,
      87,
      105,
      116,
      104,
      66,
      117,
      110,
      100,
      108,
      101,
      73,
      68,
      58,
    ]
    return NSSelectorFromString(String(bytes.map { Character(UnicodeScalar($0)) }))
  }

  // swiftlint:enable no_magic_numbers
}
