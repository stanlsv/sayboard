import Foundation
import Testing

@Suite("LLMModelVariant catalog")
struct LLMModelVariantCatalogTests {

  @Test
  func `superseded variants stay out of the catalog`() {
    #expect(!LLMModelVariant.current.contains(.qwen3Small))
    #expect(!LLMModelVariant.current.contains(.qwen3Large))
    #expect(!LLMModelVariant.current.contains(.gemma3One))
  }

  @Test
  func `current holds every variant that has no successor`() {
    #expect(LLMModelVariant.current == [.qwen35Small, .gemma3OneQAT, .llama32One, .smollm2Medium, .qwen35Large])
  }

  @Test
  func `qwen 3 points at its qwen 3_5 replacement`() {
    #expect(LLMModelVariant.qwen3Small.successor == .qwen35Small)
    #expect(LLMModelVariant.qwen3Large.successor == .qwen35Large)
  }

  @Test
  func `gemma points at its quantization-aware replacement`() {
    #expect(LLMModelVariant.gemma3One.successor == .gemma3OneQAT)
  }

  @Test
  func `a successor is never itself superseded`() {
    for variant in LLMModelVariant.allCases {
      #expect(variant.successor?.isSuperseded != true, "\(variant.rawValue) chains to a dead model")
    }
  }

  @Test
  func `isSuperseded tracks the presence of a successor`() {
    for variant in LLMModelVariant.allCases {
      #expect(variant.isSuperseded == (variant.successor != nil))
    }
  }

  @Test
  func `exactly one variant is recommended and it is current`() {
    let recommended = LLMModelVariant.allCases.filter(\.isRecommended)
    #expect(recommended == [.gemma3OneQAT])
    #expect(recommended.allSatisfy { !$0.isSuperseded })
  }

  @Test
  func `raw values are frozen`() {
    #expect(LLMModelVariant.qwen35Small.rawValue == "qwen35-0.8b-q4km")
    #expect(LLMModelVariant.qwen35Large.rawValue == "qwen35-2b-q5km")
    #expect(LLMModelVariant.qwen3Small.rawValue == "qwen3-0.6b-q5km")
    #expect(LLMModelVariant.qwen3Large.rawValue == "qwen3-1.7b-q8")
    #expect(LLMModelVariant.gemma3One.rawValue == "gemma3-1b-q5km")
    #expect(LLMModelVariant.gemma3OneQAT.rawValue == "gemma3-1b-qat-q4_0")
    #expect(LLMModelVariant.llama32One.rawValue == "llama32-1b-q5km")
    #expect(LLMModelVariant.smollm2Medium.rawValue == "smollm2-1.7b-q4km")
  }

  @Test
  func `every variant carries card copy and a gguf name`() {
    for variant in LLMModelVariant.allCases {
      #expect(!variant.displayName.isEmpty)
      #expect(!variant.descriptionKey.isEmpty)
      #expect(!variant.languageTagKey.isEmpty)
      #expect(variant.ggufFileName.hasSuffix(".gguf"))
    }
  }

  @Test
  func `gguf names are unique`() {
    let names = LLMModelVariant.allCases.map(\.ggufFileName)
    #expect(Set(names).count == names.count)
  }

  @Test
  func `a superseded variant is never the default selection`() {
    #expect(!LLMModelVariant.qwen35Small.isSuperseded)
  }

  @Test
  func `qwen 3_5 needs less memory than the qwen 3 it replaces`() {
    #expect(LLMModelVariant.qwen35Large.ramRequirementMB < LLMModelVariant.qwen3Large.ramRequirementMB)
    #expect(LLMModelVariant.qwen35Large.downloadSizeMB < LLMModelVariant.qwen3Large.downloadSizeMB)
  }

  @Test
  func `quality outweighs speed in the ranking`() {
    #expect(LLMModelVariant.qwen35Large.catalogRank > LLMModelVariant.qwen35Small.catalogRank)
  }

  @Test
  func `ranked order of the catalog is pinned`() {
    let ranked = LLMModelVariant.current.sorted { $0.catalogRank > $1.catalogRank }
    #expect(ranked == [.qwen35Large, .gemma3OneQAT, .smollm2Medium, .qwen35Small, .llama32One])
  }

  @Test
  func `no two variants share a rank`() {
    let ranks = LLMModelVariant.allCases.map(\.catalogRank)
    #expect(Set(ranks).count == ranks.count)
  }

  @Test
  func `device gate adds the shared system overhead`() {
    let overheadMB = 2000
    let bytesPerMB = 1_000_000
    let expected = UInt64((LLMModelVariant.qwen35Large.ramRequirementMB + overheadMB) * bytesPerMB)
    #expect(LLMModelVariant.qwen35Large.minRAMBytes == expected)
  }
}
