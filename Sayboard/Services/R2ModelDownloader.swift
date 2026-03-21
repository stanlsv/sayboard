// R2DownloadError -- Error types for R2 model downloads

import Foundation

// MARK: - R2DownloadError

enum R2DownloadError: LocalizedError {
  case manifestMissingVariant(String)
  case sha256Mismatch(expected: String, actual: String)
  case extractionFailed(Error)
  case downloadFailed(Error)
  case cancelled

  // MARK: Internal

  var errorDescription: String? {
    switch self {
    case .manifestMissingVariant(let name):
      "Model '\(name)' not found in manifest"
    case .sha256Mismatch(let expected, let actual):
      "SHA256 mismatch: expected \(expected), got \(actual)"
    case .extractionFailed(let error):
      "Zip extraction failed: \(error.localizedDescription)"
    case .downloadFailed(let error):
      "Download failed: \(error.localizedDescription)"
    case .cancelled:
      "Download was cancelled"
    }
  }
}
