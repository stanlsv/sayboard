import Foundation

enum SupportLinks {

  static let supportAddress = "support@sayboard.app"

  static var newIssueURL: URL? {
    var components = URLComponents(string: "https://github.com/stanlsv/sayboard/issues/new")
    components?.queryItems = [
      URLQueryItem(name: "title", value: Self.subject),
      URLQueryItem(name: "body", value: Self.body),
    ]
    return components?.url
  }

  static var supportEmailURL: URL? {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = Self.supportAddress
    components.queryItems = [
      URLQueryItem(name: "subject", value: Self.subject),
      URLQueryItem(name: "body", value: Self.body),
    ]
    return components.url
  }

  private static let subject = "Sayboard bug report"

  private static var body: String {
    """
    What happened:


    What you expected:


    ---
    Sayboard \(self.appVersion)
    iOS \(self.systemVersion)
    \(self.deviceIdentifier)
    """
  }

  private static var systemVersion: String {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    let base = "\(version.majorVersion).\(version.minorVersion)"
    return version.patchVersion > 0 ? "\(base).\(version.patchVersion)" : base
  }

  private static var appVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
  }

  private static var deviceIdentifier: String {
    if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
      return simulated
    }
    var info = utsname()
    uname(&info)
    let bytes = withUnsafeBytes(of: &info.machine) { raw in
      Array(raw.prefix { $0 != 0 })
    }
    return String(bytes: bytes, encoding: .utf8) ?? "unknown"
  }
}
