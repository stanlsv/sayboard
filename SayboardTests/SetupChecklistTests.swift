import Testing
@testable import Sayboard

@Suite("Counting unfinished setup steps")
struct SetupChecklistTests {

  @Test
  func `nothing done leaves every step`() {
    let checklist = SetupChecklist(
      microphoneGranted: false,
      keyboardAdded: false,
      fullAccessGranted: false,
      hasUsableModel: false,
    )
    #expect(checklist.remainingCount == Self.allSteps)
    #expect(!checklist.isComplete)
  }

  @Test
  func `everything done completes setup`() {
    let checklist = SetupChecklist(
      microphoneGranted: true,
      keyboardAdded: true,
      fullAccessGranted: true,
      hasUsableModel: true,
    )
    #expect(checklist.remainingCount == 0)
    #expect(checklist.isComplete)
  }

  @Test
  func `a missing microphone and model leave two steps`() {
    let checklist = SetupChecklist(
      microphoneGranted: false,
      keyboardAdded: true,
      fullAccessGranted: true,
      hasUsableModel: false,
    )
    #expect(checklist.remainingCount == Self.missingMicrophoneAndModel)
  }

  @Test
  func `a missing model alone keeps setup incomplete`() {
    let checklist = SetupChecklist(
      microphoneGranted: true,
      keyboardAdded: true,
      fullAccessGranted: true,
      hasUsableModel: false,
    )
    #expect(checklist.remainingCount == 1)
    #expect(!checklist.isComplete)
  }

  private static let allSteps = 4
  private static let missingMicrophoneAndModel = 2
}
