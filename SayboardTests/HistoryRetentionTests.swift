import Foundation
import Testing

@testable import Sayboard

@Suite("What a retention policy keeps")
struct HistoryRetentionTests {

  @Test
  func `forever keeps every record`() {
    let records = Self.records(count: 7)
    #expect(Self.store.retainedRecords(for: .forever, in: records, now: Self.now).map(\.id) == records.map(\.id))
  }

  @Test
  func `never keeps nothing`() {
    #expect(Self.store.retainedRecords(for: .never, in: Self.records(count: 7), now: Self.now).isEmpty)
  }

  @Test
  func `a count policy keeps the newest records and drops the rest`() {
    let records = Self.records(count: 7)
    let retained = Self.store.retainedRecords(for: .last5, in: records, now: Self.now)
    #expect(retained.map(\.id) == records.prefix(5).map(\.id))
  }

  @Test
  func `a count policy keeps everything when there are fewer records than the limit`() {
    let records = Self.records(count: 3)
    #expect(Self.store.retainedRecords(for: .last5, in: records, now: Self.now).count == 3)
  }

  @Test
  func `a time policy keeps records on the cutoff and drops older ones`() {
    let records = [
      Self.record(hoursAgo: 0),
      Self.record(hoursAgo: 23),
      Self.record(hoursAgo: 24),
      Self.record(hoursAgo: 25),
    ]
    let retained = Self.store.retainedRecords(for: .past24Hours, in: records, now: Self.now)
    #expect(retained.count == 3)
    #expect(!retained.contains { $0.audioFileName == "25.caf" })
  }

  @Test
  func `a week and a month keep the records their names promise`() {
    let records = [Self.record(hoursAgo: 100), Self.record(hoursAgo: 200), Self.record(hoursAgo: 800)]
    #expect(Self.store.retainedRecords(for: .pastWeek, in: records, now: Self.now).count == 1)
    #expect(Self.store.retainedRecords(for: .pastMonth, in: records, now: Self.now).count == 2)
  }

  private static let store = HistoryStore.shared
  private static let now = Date(timeIntervalSince1970: 1_790_000_000)

  private static func record(hoursAgo: Int) -> HistoryRecord {
    HistoryRecord(
      id: UUID(),
      date: Self.now.addingTimeInterval(-Double(hoursAgo) * 3600),
      duration: 1,
      transcription: "test",
      audioFileName: "\(hoursAgo).caf",
    )
  }

  private static func records(count: Int) -> [HistoryRecord] {
    (0 ..< count).map { Self.record(hoursAgo: $0) }
  }
}
