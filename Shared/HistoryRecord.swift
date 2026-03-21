import Foundation

// HistoryRecord -- A single transcription history entry

struct HistoryRecord: Codable, Identifiable, Sendable {

  // MARK: Lifecycle

  init(
    id: UUID,
    date: Date,
    duration: TimeInterval,
    transcription: String,
    audioFileName: String,
    waveformSamples: [Float] = [],
  ) {
    self.id = id
    self.date = date
    self.duration = duration
    self.transcription = transcription
    self.audioFileName = audioFileName
    self.waveformSamples = waveformSamples
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(UUID.self, forKey: .id)
    self.date = try container.decode(Date.self, forKey: .date)
    self.duration = try container.decode(TimeInterval.self, forKey: .duration)
    self.transcription = try container.decode(String.self, forKey: .transcription)
    self.audioFileName = try container.decode(String.self, forKey: .audioFileName)
    self.waveformSamples = (try? container.decode([Float].self, forKey: .waveformSamples)) ?? []
  }

  // MARK: Internal

  let id: UUID
  let date: Date
  let duration: TimeInterval
  let transcription: String
  let audioFileName: String
  let waveformSamples: [Float]

}
