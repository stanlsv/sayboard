
import Foundation

struct RememberedHost: Codable {

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

  static func matchingCurrentProcess(ttl: TimeInterval) -> Self? {
    guard let current = currentProcess else { return nil }
    let now = CFAbsoluteTimeGetCurrent()
    return self.table.first {
      $0.pid == current.pid && $0.pidVersion == current.version && now - $0.at < ttl
    }
  }

  static func remember(_ bundleId: String) {
    guard let current = currentProcess else { return }
    let entry = Self(
      bundleId: bundleId,
      pid: current.pid,
      pidVersion: current.version,
      at: CFAbsoluteTimeGetCurrent(),
    )
    var kept = self.table.filter { $0.bundleId != bundleId }
    kept.insert(entry, at: 0)
    self.table = Array(kept.prefix(self.tableLimit))
  }

  private static let tableLimit = 32

  private static var store: UserDefaults? {
    AppGroup.sharedDefaults
  }

  private static var table: [Self] {
    get {
      guard let data = store?.data(forKey: SharedKey.rememberedHosts) else { return [] }
      return (try? JSONDecoder().decode([Self].self, from: data)) ?? []
    }
    set {
      self.store?.set(try? JSONEncoder().encode(newValue), forKey: SharedKey.rememberedHosts)
    }
  }
}
