import Foundation

// MARK: - HistoryStore

// HistoryStore -- CRUD + auto-delete for transcription history
// Stores metadata as JSON in the App Group container.
// Audio files live in an `audio/` subdirectory of the same container.

struct HistoryStore: Sendable {

  // MARK: Internal

  static let shared = Self()

  var audioDirectoryURL: URL? {
    guard let container = AppGroup.containerURL else { return nil }
    let audioDir = container.appendingPathComponent(self.audioDirectoryName)
    if !FileManager.default.fileExists(atPath: audioDir.path) {
      try? FileManager.default.createDirectory(
        at: audioDir,
        withIntermediateDirectories: true,
        attributes: [.protectionKey: FileProtectionType.completeUnlessOpen],
      )
    }
    return audioDir
  }

  func audioFileURL(for fileName: String) -> URL? {
    self.audioDirectoryURL?.appendingPathComponent(fileName)
  }

  func audioStorageSize() -> Int64 {
    guard let url = audioDirectoryURL else { return 0 }
    guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
    guard
      let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.fileSizeKey],
      )
    else {
      return 0
    }
    var total: Int64 = 0
    for case let fileURL as URL in enumerator {
      if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
        total += Int64(size)
      }
    }
    return total
  }

  func loadRecords() -> [HistoryRecord] {
    guard let url = historyFileURL else { return [] }
    guard let data = try? Data(contentsOf: url) else { return [] }
    let records = (try? JSONDecoder.historyDecoder.decode([HistoryRecord].self, from: data)) ?? []
    return records.sorted { $0.date > $1.date }
  }

  func saveRecord(_ record: HistoryRecord) {
    guard SharedSettings().retentionPolicy != .never else {
      self.deleteAudioFile(named: record.audioFileName)
      return
    }
    var records = self.loadRecords()
    records.insert(record, at: 0)
    self.writeRecords(records)
  }

  func deleteRecord(id: UUID) {
    var records = self.loadRecords()
    guard let index = records.firstIndex(where: { $0.id == id }) else { return }
    let record = records[index]
    self.deleteAudioFile(named: record.audioFileName)
    records.remove(at: index)
    self.writeRecords(records)
  }

  func deleteAllRecords() {
    let records = self.loadRecords()
    for record in records {
      self.deleteAudioFile(named: record.audioFileName)
    }
    self.writeRecords([])
  }

  func recordsToDeleteCount(for policy: HistoryRetentionPolicy) -> Int {
    let records = self.loadRecords()
    let retainedCount: Int =
      switch policy {
      case .never: 0
      case .last5: min(records.count, self.countLimit5)
      case .last25: min(records.count, self.countLimit25)
      case .last50: min(records.count, self.countLimit50)
      case .last100: min(records.count, self.countLimit100)
      case .last500: min(records.count, self.countLimit500)
      case .past24Hours: self.countNewerThan(hours: self.hoursInDay, in: records)
      case .pastWeek: self.countNewerThan(hours: self.hoursInWeek, in: records)
      case .pastMonth: self.countNewerThan(hours: self.hoursInMonth, in: records)
      case .forever: records.count
      }
    return records.count - retainedCount
  }

  func applyRetentionPolicy() {
    let policy = SharedSettings().retentionPolicy
    let records = self.loadRecords()

    let retained: [HistoryRecord] =
      switch policy {
      case .never: self.clearAllAudio(in: records)
      case .last5: self.applyCountLimit(self.countLimit5, to: records)
      case .last25: self.applyCountLimit(self.countLimit25, to: records)
      case .last50: self.applyCountLimit(self.countLimit50, to: records)
      case .last100: self.applyCountLimit(self.countLimit100, to: records)
      case .last500: self.applyCountLimit(self.countLimit500, to: records)
      case .past24Hours: self.removeOlderThan(hours: self.hoursInDay, from: records)
      case .pastWeek: self.removeOlderThan(hours: self.hoursInWeek, from: records)
      case .pastMonth: self.removeOlderThan(hours: self.hoursInMonth, from: records)
      case .forever: records
      }

    self.writeRecords(retained)
  }

  // MARK: Private

  private let historyFileName = "history.json"
  private let audioDirectoryName = "audio"

  private let countLimit5 = 5
  private let countLimit25 = 25
  private let countLimit50 = 50
  private let countLimit100 = 100
  private let countLimit500 = 500

  private let hoursInDay = 24
  private let hoursInWeek = 168
  private let hoursInMonth = 720

  private var historyFileURL: URL? {
    AppGroup.containerURL?.appendingPathComponent(self.historyFileName)
  }

  private func writeRecords(_ records: [HistoryRecord]) {
    guard let url = historyFileURL else { return }
    guard let data = try? JSONEncoder.historyEncoder.encode(records) else { return }
    try? data.write(to: url, options: [.atomic, .completeFileProtection])
  }

  private func deleteAudioFile(named fileName: String) {
    guard let url = audioFileURL(for: fileName) else { return }
    try? FileManager.default.removeItem(at: url)
  }

  private func applyCountLimit(_ limit: Int, to records: [HistoryRecord]) -> [HistoryRecord] {
    guard records.count > limit else { return records }

    let excess = Array(records.suffix(from: limit))
    for record in excess {
      self.deleteAudioFile(named: record.audioFileName)
    }
    return Array(records.prefix(limit))
  }

  private func clearAllAudio(in records: [HistoryRecord]) -> [HistoryRecord] {
    for record in records {
      self.deleteAudioFile(named: record.audioFileName)
    }
    return []
  }

  private func countNewerThan(hours: Int, in records: [HistoryRecord]) -> Int {
    let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
    // swiftformat:disable:next preferCountWhere
    return records.filter { $0.date >= cutoff }.count
  }

  private func removeOlderThan(hours: Int, from records: [HistoryRecord]) -> [HistoryRecord] {
    let cutoff = Date().addingTimeInterval(-Double(hours) * 3600)
    let expired = records.filter { $0.date < cutoff }
    for record in expired {
      self.deleteAudioFile(named: record.audioFileName)
    }
    return records.filter { $0.date >= cutoff }
  }
}

extension JSONDecoder {
  fileprivate static let historyDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }()
}

extension JSONEncoder {
  fileprivate static let historyEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted
    return encoder
  }()
}
