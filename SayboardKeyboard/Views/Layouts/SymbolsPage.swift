import Foundation

enum SymbolsPage {
  case numbers
  case symbols

  var togglerLabel: String {
    switch self {
    case .numbers: "#+="
    case .symbols: "123"
    }
  }

  var toggled: Self {
    switch self {
    case .numbers: .symbols
    case .symbols: .numbers
    }
  }
}
