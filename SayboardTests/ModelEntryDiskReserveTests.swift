import Foundation
import Testing

@testable import Sayboard

@Suite("Disk reserve for a model download")
struct ModelEntryDiskReserveTests {

  static let speechArchive: Int64 = 477_316_682
  static let speechExpanded: Int64 = 495_761_847

  @Test
  func `the expanded size is optional in the wire format`() throws {
    let json = Data(
      """
      {"url":"https://example.com/m.zip","sha256":"abc","sizeBytes":477316682,"engine":"parakeet"}
      """.utf8
    )
    let entry = try JSONDecoder().decode(ModelEntry.self, from: json)
    #expect(entry.expandedBytes == nil)
  }

  @Test
  func `a published expanded size is added to the archive`() throws {
    let entry = try Self.decode(sizeBytes: Self.speechArchive, expandedBytes: Self.speechExpanded)
    #expect(entry.peakDiskBytes == Self.speechArchive + Self.speechExpanded)
  }

  @Test
  func `an entry without an expanded size reserves more than the real peak, never less`() throws {
    let measured = try Self.decode(sizeBytes: Self.speechArchive, expandedBytes: Self.speechExpanded)
    let unmeasured = try Self.decode(sizeBytes: Self.speechArchive, expandedBytes: nil)
    #expect(unmeasured.peakDiskBytes > measured.peakDiskBytes)
  }

  @Test
  func `a text model without an expanded size falls back to twice its archive`() throws {
    let gemma3QATArchive: Int64 = 720_425_924
    let json = Data(
      """
      {"url":"https://example.com/m.zip","sha256":"abc","sizeBytes":\(gemma3QATArchive)}
      """.utf8
    )
    let entry = try JSONDecoder().decode(LLMModelEntry.self, from: json)
    #expect(entry.expandedBytes == nil)
    #expect(entry.peakDiskBytes == gemma3QATArchive * 2)
  }

  @Test
  func `a deflated text archive stays inside the reserve its fallback earns`() throws {
    let archive: Int64 = 562_648_859
    let expanded: Int64 = 579_615_840
    let json = Data(
      """
      {"url":"https://example.com/m.zip","sha256":"abc","sizeBytes":\(archive)}
      """.utf8
    )
    let entry = try JSONDecoder().decode(LLMModelEntry.self, from: json)
    #expect(ModelDiskReserve.requiredBytes(peak: entry.peakDiskBytes) > archive + expanded)
  }

  @Test
  func `a published expanded size overrides the text fallback`() throws {
    let archive: Int64 = 562_648_859
    let expanded: Int64 = 579_615_840
    let json = Data(
      """
      {"url":"https://example.com/m.zip","sha256":"abc","sizeBytes":\(archive),"expandedBytes":\(expanded)}
      """.utf8
    )
    let entry = try JSONDecoder().decode(LLMModelEntry.self, from: json)
    #expect(entry.peakDiskBytes == archive + expanded)
  }

  @Test
  func `the reserve sits above the peak without doubling it`() {
    let peak: Int64 = 1_440_851_848
    let required = ModelDiskReserve.requiredBytes(peak: peak)
    #expect(required > peak)
    #expect(required < peak * 2)
  }

  @Test
  func `the largest catalogue entry does not overflow the reserve arithmetic`() {
    let peak: Int64 = 2_165_000_000 * 2
    #expect(ModelDiskReserve.requiredBytes(peak: peak) > peak)
  }

  private static func decode(sizeBytes: Int64, expandedBytes: Int64?) throws -> ModelEntry {
    let expanded = expandedBytes.map { ",\"expandedBytes\":\($0)" } ?? ""
    let json = Data(
      """
      {"url":"https://example.com/m.zip","sha256":"abc","sizeBytes":\(sizeBytes)\(expanded),"engine":"parakeet"}
      """.utf8
    )
    return try JSONDecoder().decode(ModelEntry.self, from: json)
  }
}
