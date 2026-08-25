import Foundation

enum OperatingSystem {

  static let isHostBundleIdBroken: Bool = ProcessInfo.processInfo
    .isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0))

  static let isBackgroundNeuralEngineBlocked: Bool = ProcessInfo.processInfo
    .isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 27, minorVersion: 0, patchVersion: 0))
}
