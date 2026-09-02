import Foundation
import Testing

@Suite("Int.megabytesInBytes")
struct MegabyteUnitTests {

  @Test
  func `a megabyte is decimal`() {
    #expect(1.megabytesInBytes == 1_000_000)
    #expect(1.megabytesInBytes != 1024 * 1024)
  }

  @Test
  func `conversion scales linearly`() {
    #expect(0.megabytesInBytes == 0)
    #expect(850.megabytesInBytes == 850_000_000)
    #expect(2000.megabytesInBytes == 2_000_000_000)
  }

  @Test
  func `formatting reads the same unit as the gates`() {
    let formatted = 850.formattedAsBytes(locale: Locale(identifier: "en_US"))
    #expect(formatted.contains("850"))
  }

  @Test
  func `llm device gate is built from the shared unit`() {
    let overheadMB = 2000
    for variant in LLMModelVariant.allCases {
      #expect(variant.minRAMBytes == UInt64((variant.ramRequirementMB + overheadMB) * 1_000_000))
    }
  }

  @Test
  func `every stt model clears its own threshold on any shipping device`() {
    let smallestShippingDeviceBytes: UInt64 = 2 * 1024 * 1024 * 1024
    for variant in ModelVariant.allCases {
      #expect(variant.ramRequirementMB.megabytesInBytes < smallestShippingDeviceBytes)
    }
  }

  @Test
  func `a declared device floor excludes 4GB phones and admits 6GB ones`() {
    let fourGigabyteDeviceBytes: UInt64 = 3_940_000_000
    let sixGigabyteDeviceBytes: UInt64 = 5_913_000_000

    for variant in ModelVariant.allCases {
      guard let floor = variant.minimumDeviceMemoryMB else { continue }
      #expect(floor.megabytesInBytes > fourGigabyteDeviceBytes)
      #expect(floor.megabytesInBytes <= sixGigabyteDeviceBytes)
    }
  }

  @Test
  func `a device floor never doubles as the advertised RAM figure`() {
    for variant in ModelVariant.allCases {
      guard let floor = variant.minimumDeviceMemoryMB else { continue }
      #expect(variant.ramRequirementMB < floor)
    }
  }
}
