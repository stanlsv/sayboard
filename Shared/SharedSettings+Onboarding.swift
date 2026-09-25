
import Foundation

extension SharedSettings {

  var onboardingPracticeProcessID: Int? {
    get {
      let pid = self.defaults.integer(forKey: SharedKey.onboardingPracticePid)
      return pid > 0 ? pid : nil
    }
    nonmutating set {
      self.defaults.set(newValue ?? 0, forKey: SharedKey.onboardingPracticePid)
      self.defaults.set(newValue == nil ? 0 : CFAbsoluteTimeGetCurrent(), forKey: SharedKey.onboardingPracticeAt)
    }
  }

  var isMicHintDismissed: Bool {
    get { self.defaults.bool(forKey: SharedKey.micHintDismissed) }
    nonmutating set { self.defaults.set(newValue, forKey: SharedKey.micHintDismissed) }
  }

  func isOnboardingPracticeHost(_ hostProcessID: Int?, now: TimeInterval = CFAbsoluteTimeGetCurrent()) -> Bool {
    guard let practice = self.onboardingPracticeProcessID else { return false }
    let markedAt = self.defaults.double(forKey: SharedKey.onboardingPracticeAt)
    guard markedAt > 0, now - markedAt < Self.practiceMarkTTL else { return false }
    return hostProcessID.map { $0 == practice } ?? true
  }

  func showsMicHint(hostProcessID: Int?) -> Bool {
    self.isOnboardingPracticeHost(hostProcessID) && !self.isMicHintDismissed
  }

  private static let practiceMarkTTL: TimeInterval = 30 * 60
}
