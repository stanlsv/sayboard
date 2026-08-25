
import Foundation

enum R2DownloadError: LocalizedError {
  case manifestMissingVariant(String)
  case appTooOldForModel
  case sha256Mismatch(expected: String, actual: String)
  case extractionFailed(Error)
  case extractionRanOutOfSpace
  case downloadFailed(Error)
  case cancelled

  var errorDescription: String? {
    switch self {
    case .manifestMissingVariant(let name):
      "Model '\(name)' not found in manifest"
    case .appTooOldForModel:
      "This model needs a newer version of Sayboard"
    case .sha256Mismatch(let expected, let actual):
      "SHA256 mismatch: expected \(expected), got \(actual)"
    case .extractionFailed(let error):
      "Zip extraction failed: \(error.localizedDescription)"
    case .extractionRanOutOfSpace:
      "Zip extraction ran out of disk space"
    case .downloadFailed(let error):
      "Download failed: \(error.localizedDescription)"
    case .cancelled:
      "Download was cancelled"
    }
  }
}
