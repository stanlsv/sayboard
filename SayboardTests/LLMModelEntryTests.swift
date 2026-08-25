import Foundation
import Testing

@testable import Sayboard

@Suite("LLMModelEntry.isLoadableByThisBuild")
struct LLMModelEntryTests {

  @Test
  func `an entry without a requirement loads anywhere`() {
    #expect(Self.entry(minLlamaBuild: nil).isLoadableByThisBuild)
  }

  @Test
  func `a requirement below the linked build passes`() {
    #expect(Self.entry(minLlamaBuild: LlamaRuntime.buildNumber - 1).isLoadableByThisBuild)
  }

  @Test
  func `a requirement equal to the linked build passes`() {
    #expect(Self.entry(minLlamaBuild: LlamaRuntime.buildNumber).isLoadableByThisBuild)
  }

  @Test
  func `a requirement above the linked build is refused`() {
    #expect(!Self.entry(minLlamaBuild: LlamaRuntime.buildNumber + 1).isLoadableByThisBuild)
  }

  @Test
  func `the field is optional in the wire format`() throws {
    let json = Data(
      """
      {"url":"https://example.com/m.zip","sha256":"abc","sizeBytes":123}
      """.utf8
    )
    let entry = try JSONDecoder().decode(LLMModelEntry.self, from: json)
    #expect(entry.minLlamaBuild == nil)
    #expect(entry.isLoadableByThisBuild)
  }

  @Test
  func `the field decodes when present`() throws {
    let json = Data(
      """
      {"url":"https://example.com/m.zip","sha256":"abc","sizeBytes":123,"minLlamaBuild":9180}
      """.utf8
    )
    let entry = try JSONDecoder().decode(LLMModelEntry.self, from: json)
    #expect(entry.minLlamaBuild == 9180)
  }

  @Test
  func `the shipped build satisfies what the qwen 3_5 models need`() {
    #expect(LlamaRuntime.buildNumber >= 9180)
  }

  private static func entry(minLlamaBuild: Int?) -> LLMModelEntry {
    let requirement = minLlamaBuild.map { ",\"minLlamaBuild\":\($0)" } ?? ""
    let json = Data(
      """
      {"url":"https://example.com/m.zip","sha256":"abc","sizeBytes":1\(requirement)}
      """.utf8
    )
    return try! JSONDecoder().decode(LLMModelEntry.self, from: json)
  }
}
