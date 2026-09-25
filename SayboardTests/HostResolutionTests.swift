import Foundation
import Testing

@Suite("Resolving the app the keyboard is in")
struct HostResolutionTests {

  @Test
  func `a capture during this appearance names the host and remembers its process`() {
    let resolution = HostFixture.resolve(capture: (HostFixture.telegram, HostFixture.afterAppearance))
    #expect(resolution.bundleId == HostFixture.telegram)
    #expect(resolution.source == .freshCapture)
    #expect(resolution.table == [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.now)])
  }

  @Test
  func `a capture that lands just before the keyboard appears names the host without being remembered`() {
    let resolution = HostFixture.resolve(capture: (HostFixture.telegram, HostFixture.justBeforeAppearance))
    #expect(resolution.bundleId == HostFixture.telegram)
    #expect(resolution.source == .earlyCapture)
    #expect(resolution.table.isEmpty)
  }

  @Test
  func `an early capture does not override the remembered process`() {
    let table = [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.recently)]
    let resolution = HostFixture.resolve(
      capture: (HostFixture.focus, HostFixture.justBeforeAppearance),
      table: table,
    )
    #expect(resolution.bundleId == HostFixture.telegram)
    #expect(resolution.source == .rememberedProcess)
    #expect(resolution.table == table)
  }

  @Test
  func `the early-capture margin reaches exactly its length before the appearance`() {
    let atEdge = HostFixture.resolve(capture: (HostFixture.telegram, HostFixture.appearedAt - HostFixture.captureLead))
    let pastEdge = HostFixture.resolve(
      capture: (HostFixture.telegram, HostFixture.appearedAt - HostFixture.pastCaptureLead),
      previous: HostFixture.focus,
    )
    #expect(atEdge.source == .earlyCapture)
    #expect(pastEdge.source == .previousValue)
    #expect(pastEdge.bundleId == HostFixture.focus)
  }

  @Test
  func `a capture from an earlier appearance is not trusted`() {
    let resolution = HostFixture.resolve(
      capture: (HostFixture.focus, HostFixture.longBeforeAppearance),
      previous: HostFixture.focus,
    )
    #expect(resolution.bundleId == HostFixture.focus)
    #expect(resolution.source == .previousValue)
    #expect(resolution.table.isEmpty)
  }

  @Test
  func `a remembered process names the host when the hook has nothing`() {
    let table = [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.recently)]
    let resolution = HostFixture.resolve(previous: HostFixture.settingsApp, table: table)
    #expect(resolution.bundleId == HostFixture.telegram)
    #expect(resolution.source == .rememberedProcess)
    #expect(resolution.table == table)
  }

  @Test
  func `a stale capture does not override the remembered process`() {
    let table = [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.recently)]
    let resolution = HostFixture.resolve(
      capture: (HostFixture.focus, HostFixture.longBeforeAppearance),
      previous: HostFixture.focus,
      table: table,
    )
    #expect(resolution.bundleId == HostFixture.telegram)
    #expect(resolution.source == .rememberedProcess)
    #expect(resolution.table == table)
  }

  @Test
  func `another process's entry does not name this host`() {
    let resolution = HostFixture.resolve(
      previous: HostFixture.focus,
      table: [HostFixture.entry(HostFixture.focus, HostFixture.focusProcess, HostFixture.recently)],
    )
    #expect(resolution.bundleId == HostFixture.focus)
    #expect(resolution.source == .previousValue)
  }

  @Test
  func `a reused pid from another generation does not name this host`() {
    let resolution = HostFixture.resolve(
      previous: HostFixture.focus,
      table: [HostFixture.entry(HostFixture.settingsApp, HostFixture.reusedTelegramPid, HostFixture.recently)],
    )
    #expect(resolution.bundleId == HostFixture.focus)
    #expect(resolution.source == .previousValue)
  }

  @Test
  func `a fresh capture keeps a reused pid's entry`() {
    let reused = HostFixture.entry(HostFixture.settingsApp, HostFixture.reusedTelegramPid, HostFixture.recently)
    let resolution = HostFixture.resolve(
      capture: (HostFixture.telegram, HostFixture.afterAppearance),
      table: [reused],
    )
    #expect(resolution.table == [
      HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.now),
      reused,
    ])
  }

  @Test
  func `an entry exactly at the trust window no longer names the host`() {
    let resolution = HostFixture.resolve(
      previous: HostFixture.focus,
      table: [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.now - HostFixture.trustWindow)],
    )
    #expect(resolution.bundleId == HostFixture.focus)
    #expect(resolution.source == .previousValue)
  }

  @Test
  func `an entry a second inside the trust window names the host`() {
    let insideWindow = HostFixture.now - HostFixture.trustWindow + HostFixture.oneSecond
    let resolution = HostFixture.resolve(
      previous: HostFixture.focus,
      table: [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, insideWindow)],
    )
    #expect(resolution.bundleId == HostFixture.telegram)
    #expect(resolution.source == .rememberedProcess)
  }

  @Test
  func `an entry from another boot does not name the host`() {
    let resolution = HostFixture.resolve(
      previous: HostFixture.focus,
      table: [
        HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.recently, boot: HostFixture.previousBoot)
      ],
    )
    #expect(resolution.bundleId == HostFixture.focus)
    #expect(resolution.source == .previousValue)
  }

  @Test
  func `entries are trusted by age alone when the boot time cannot be read`() {
    let resolution = HostFixture.resolve(
      previous: HostFixture.focus,
      table: [
        HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.recently, boot: HostFixture.previousBoot)
      ],
      boot: nil,
    )
    #expect(resolution.bundleId == HostFixture.telegram)
    #expect(resolution.source == .rememberedProcess)
  }

  @Test
  func `nothing known leaves the host unset`() {
    let resolution = HostFixture.resolve()
    #expect(resolution.bundleId == nil)
    #expect(resolution.source == .previousValue)
  }

  @Test
  func `a fresh capture that disagrees with the remembered process wins`() {
    let resolution = HostFixture.resolve(
      capture: (HostFixture.telegram, HostFixture.afterAppearance),
      table: [HostFixture.entry(HostFixture.focus, HostFixture.telegramProcess, HostFixture.recently)],
    )
    #expect(resolution.bundleId == HostFixture.telegram)
    #expect(resolution.table == [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.now)])
  }

  @Test
  func `an expired claim on the process is replaced`() {
    let resolution = HostFixture.resolve(
      capture: (HostFixture.telegram, HostFixture.afterAppearance),
      table: [HostFixture.entry(HostFixture.focus, HostFixture.telegramProcess, HostFixture.longAgo)],
    )
    #expect(resolution.table == [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.now)])
  }

  @Test
  func `capturing the remembered app again refreshes its entry`() {
    let resolution = HostFixture.resolve(
      capture: (HostFixture.telegram, HostFixture.afterAppearance),
      table: [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.recently)],
    )
    #expect(resolution.table == [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.now)])
  }

  @Test
  func `a relaunched app replaces its old process rather than adding a row`() {
    let resolution = HostFixture.resolve(
      capture: (HostFixture.telegram, HostFixture.afterAppearance),
      table: [HostFixture.entry(HostFixture.telegram, HostFixture.relaunchedTelegramOldProcess, HostFixture.recently)],
    )
    #expect(resolution.table == [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.now)])
  }

  @Test
  func `other apps' entries survive a fresh capture`() {
    let focusEntry = HostFixture.entry(HostFixture.focus, HostFixture.focusProcess, HostFixture.recently)
    let resolution = HostFixture.resolve(
      capture: (HostFixture.telegram, HostFixture.afterAppearance),
      table: [focusEntry],
    )
    #expect(resolution.table == [
      HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.now),
      focusEntry,
    ])
  }

  @Test
  func `the table keeps its newest entries up to its limit`() {
    let full = (0..<HostFixture.tableLimit).map { index in
      HostFixture.entry("app.test.\(index)", (pid: HostFixture.firstFillerPid + index, version: 1), HostFixture.recently)
    }
    let resolution = HostFixture.resolve(
      capture: (HostFixture.telegram, HostFixture.afterAppearance),
      table: full,
    )
    #expect(resolution.table.count == HostFixture.tableLimit)
    #expect(resolution.table.first == HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.now))
    #expect(resolution.table.last == full[HostFixture.tableLimit - 2])
  }

  @Test
  func `without a process identity a fresh capture names the host and leaves the table alone`() {
    let table = [HostFixture.entry(HostFixture.focus, HostFixture.telegramProcess, HostFixture.recently)]
    let resolution = HostFixture.resolve(
      process: nil,
      capture: (HostFixture.telegram, HostFixture.afterAppearance),
      table: table,
    )
    #expect(resolution.bundleId == HostFixture.telegram)
    #expect(resolution.source == .freshCapture)
    #expect(resolution.table == table)
  }

  @Test
  func `without a process identity a stale capture falls back to the stored value`() {
    let resolution = HostFixture.resolve(
      process: nil,
      capture: (HostFixture.focus, HostFixture.longBeforeAppearance),
      previous: HostFixture.settingsApp,
      table: [HostFixture.entry(HostFixture.telegram, HostFixture.telegramProcess, HostFixture.recently)],
    )
    #expect(resolution.bundleId == HostFixture.settingsApp)
    #expect(resolution.source == .previousValue)
  }
}

private enum HostFixture {

  static let telegram = "ph.telegra.Telegraph"
  static let focus = "org.mozilla.ios.Focus"
  static let settingsApp = "com.apple.Preferences"

  static let telegramProcess = (pid: 5026, version: 12675)
  static let focusProcess = (pid: 1856, version: 4841)
  static let relaunchedTelegramOldProcess = (pid: 4011, version: 9120)
  static let reusedTelegramPid = (pid: 5026, version: 1)
  static let firstFillerPid = 100

  static let boot = 1_789_000_000
  static let previousBoot = 1_788_900_000

  static let captureLead: TimeInterval = 0.25
  static let pastCaptureLead: TimeInterval = 0.3
  static let trustWindow: TimeInterval = 12 * 60 * 60
  static let tableLimit = 32
  static let oneSecond: TimeInterval = 1

  static let appearedAt: TimeInterval = 800_000_000
  static let justBeforeAppearance = appearedAt - 0.05
  static let afterAppearance = appearedAt + 2
  static let longBeforeAppearance = appearedAt - 600
  static let now = appearedAt + 3
  static let recently = now - 60
  static let longAgo = now - 2 * 24 * 60 * 60

  static func entry(
    _ bundleId: String,
    _ process: (pid: Int, version: Int),
    _ at: TimeInterval,
    boot: Int? = Self.boot,
  ) -> RememberedHost {
    RememberedHost(bundleId: bundleId, pid: process.pid, pidVersion: process.version, at: at, boot: boot)
  }

  static func resolve(
    process: (pid: Int, version: Int)? = telegramProcess,
    capture: (bundleId: String, at: TimeInterval)? = nil,
    previous: String? = nil,
    table: [RememberedHost] = [],
    boot: Int? = Self.boot,
  ) -> HostResolution {
    RememberedHost.resolve(
      process: process,
      capture: capture,
      appearedAt: self.appearedAt,
      previous: previous,
      table: table,
      now: self.now,
      boot: boot,
    )
  }
}
