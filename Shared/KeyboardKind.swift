import Foundation

// MARK: - KeyboardKind

enum KeyboardKind: String, CaseIterable, Sendable {
  case standard
  case extended

  // MARK: Internal

  var displayNameKey: String {
    switch self {
    case .standard: "Standard"
    case .extended: "Extended"
    }
  }
}
