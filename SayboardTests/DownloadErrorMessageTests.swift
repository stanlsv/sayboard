import Foundation
import Testing

@testable import Sayboard

private enum OpaqueUnwritableFile: Error {
  case unwritableFile
}

@Suite("localizedDownloadError")
struct DownloadErrorMessageTests {

  @Test
  func `a full volume during extraction is named as out of space`() {
    #expect(localizedDownloadError(R2DownloadError.extractionRanOutOfSpace) ==
      "Not enough storage space. Free up space and try again.")
  }

  @Test
  func `an opaque extraction failure the volume survived stays generic`() {
    let wrapped = R2DownloadError.extractionFailed(OpaqueUnwritableFile.unwritableFile)
    #expect(localizedDownloadError(wrapped) == "Download failed. Tap Retry to try again.")
  }

  @Test
  func `out of space wrapped in extractionFailed is named as out of space`() {
    let full = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
    let wrapped = R2DownloadError.extractionFailed(full)
    #expect(localizedDownloadError(wrapped) == "Not enough storage space. Free up space and try again.")
  }

  @Test
  func `posix ENOSPC wrapped in extractionFailed is named as out of space`() {
    let full = NSError(domain: NSPOSIXErrorDomain, code: 28)
    let wrapped = R2DownloadError.extractionFailed(full)
    #expect(localizedDownloadError(wrapped) == "Not enough storage space. Free up space and try again.")
  }

  @Test
  func `out of space nested under NSUnderlyingErrorKey is found`() {
    let full = NSError(domain: NSPOSIXErrorDomain, code: 28)
    let outer = NSError(
      domain: NSCocoaErrorDomain,
      code: NSFileWriteUnknownError,
      userInfo: [NSUnderlyingErrorKey: full],
    )
    #expect(localizedDownloadError(R2DownloadError.extractionFailed(outer)) ==
      "Not enough storage space. Free up space and try again.")
  }

  @Test
  func `bare out of space error is named as out of space`() {
    let full = NSError(domain: NSPOSIXErrorDomain, code: 28)
    #expect(localizedDownloadError(full) == "Not enough storage space. Free up space and try again.")
  }

  @Test
  func `extraction failure that is not about space stays generic`() {
    let other = NSError(domain: NSCocoaErrorDomain, code: NSFileReadCorruptFileError)
    #expect(localizedDownloadError(R2DownloadError.extractionFailed(other)) == "Download failed. Tap Retry to try again.")
  }

  @Test
  func `app too old wins over everything else`() {
    #expect(localizedDownloadError(R2DownloadError.appTooOldForModel) == "Update Sayboard to use this model.")
  }

  @Test
  func `no internet keeps its own message`() {
    let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
    #expect(localizedDownloadError(offline) == "No internet connection. Check your network and try again.")
  }

}
