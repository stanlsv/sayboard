
struct SetupChecklist: Equatable, Sendable {

  let microphoneGranted: Bool
  let keyboardAdded: Bool
  let fullAccessGranted: Bool
  let hasUsableModel: Bool

  var remainingCount: Int {
    [self.microphoneGranted, self.keyboardAdded, self.fullAccessGranted, self.hasUsableModel]
      .count { !$0 }
  }

  var isComplete: Bool {
    self.remainingCount == 0
  }
}
