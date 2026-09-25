
import Foundation

enum HostResolutionSource: String {
  case freshCapture
  case rememberedProcess
  case earlyCapture
  case previousValue
}

struct HostResolution {
  let bundleId: String?
  let source: HostResolutionSource
  let table: [RememberedHost]
}

struct RememberedHost: Codable, Equatable {

  static let trustWindow: TimeInterval = 12 * 60 * 60

  static let currentBoot: Int? = {
    var value = timeval()
    var size = MemoryLayout<timeval>.size
    guard sysctlbyname("kern.boottime", &value, &size, nil, 0) == 0 else { return nil }
    return value.tv_sec
  }()

  static var currentProcess: (pid: Int, version: Int)? {
    get {
      guard let store, case let pid = store.integer(forKey: SharedKey.hostPid), pid > 0 else {
        return nil
      }
      return (pid, store.integer(forKey: SharedKey.hostPidVersion))
    }
    set {
      self.store?.set(newValue?.pid ?? 0, forKey: SharedKey.hostPid)
      self.store?.set(newValue?.version ?? 0, forKey: SharedKey.hostPidVersion)
    }
  }

  let bundleId: String
  let pid: Int
  let pidVersion: Int
  let at: TimeInterval
  let boot: Int?

  static func matchingCurrentProcess() -> Self? {
    guard let current = currentProcess else { return nil }
    let now = CFAbsoluteTimeGetCurrent()
    return self.table.first { $0.isTrusted(for: current, now: now, boot: self.currentBoot) }
  }

  static func resolve(
    process: (pid: Int, version: Int)?,
    capture: (bundleId: String, at: TimeInterval)?,
    appearedAt: TimeInterval,
    previous: String?,
    table: [Self],
    now: TimeInterval = CFAbsoluteTimeGetCurrent(),
    boot: Int? = currentBoot,
  ) -> HostResolution {
    if let capture, capture.at >= appearedAt {
      guard let process else {
        return HostResolution(bundleId: capture.bundleId, source: .freshCapture, table: table)
      }
      let entry = Self(bundleId: capture.bundleId, pid: process.pid, pidVersion: process.version, at: now, boot: boot)
      return HostResolution(bundleId: capture.bundleId, source: .freshCapture, table: self.inserting(entry, into: table))
    }
    if let process, let trusted = table.first(where: { $0.isTrusted(for: process, now: now, boot: boot) }) {
      return HostResolution(bundleId: trusted.bundleId, source: .rememberedProcess, table: table)
    }
    if let capture, capture.at >= appearedAt - self.captureLead {
      return HostResolution(bundleId: capture.bundleId, source: .earlyCapture, table: table)
    }
    return HostResolution(bundleId: previous, source: .previousValue, table: table)
  }

  static func resolveStored(
    process: (pid: Int, version: Int)?,
    capture: (bundleId: String, at: TimeInterval)?,
    appearedAt: TimeInterval,
    previous: String?,
  ) -> HostResolution {
    let stored = self.table
    let resolution = self.resolve(
      process: process,
      capture: capture,
      appearedAt: appearedAt,
      previous: previous,
      table: stored,
    )
    if resolution.table != stored {
      self.table = resolution.table
    }
    return resolution
  }

  private static let captureLead: TimeInterval = 0.25

  private static let tableLimit = 32

  private static var store: UserDefaults? {
    AppGroup.sharedDefaults
  }

  private static var table: [Self] {
    get {
      guard let data = store?.data(forKey: SharedKey.rememberedHostsByProcess) else { return [] }
      return (try? JSONDecoder().decode([Self].self, from: data)) ?? []
    }
    set {
      self.store?.set(try? JSONEncoder().encode(newValue), forKey: SharedKey.rememberedHostsByProcess)
    }
  }

  private static func inserting(_ entry: Self, into table: [Self]) -> [Self] {
    let process = (pid: entry.pid, version: entry.pidVersion)
    var kept = table.filter { $0.bundleId != entry.bundleId && !$0.names(process) }
    kept.insert(entry, at: 0)
    return Array(kept.prefix(self.tableLimit))
  }

  private func names(_ process: (pid: Int, version: Int)) -> Bool {
    self.pid == process.pid && self.pidVersion == process.version
  }

  private func isTrusted(for process: (pid: Int, version: Int), now: TimeInterval, boot: Int?) -> Bool {
    guard self.names(process), now - self.at < Self.trustWindow else { return false }
    guard let boot, let entryBoot = self.boot else { return true }
    return boot == entryBoot
  }
}
