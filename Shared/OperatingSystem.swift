import Foundation

// MARK: - OperatingSystem

enum OperatingSystem {

  // MARK: Internal

  /// True on iOS 26.4+, where Apple's fix for FB:165479264 regressed
  /// `xpc_connection_copy_bundle_id` and broke every keyboard-extension
  /// strategy for resolving the host bundle ID.
  ///
  /// https://keyboardkit.com/blog/2026/03/02/ios-26-4-host-application-bundle-id-bug
  static let isHostBundleIdBroken: Bool = ProcessInfo.processInfo
    .isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0))
}
