
import Foundation

import ZIPFoundation

extension BackgroundDownloadManager {

  func reconcileMetadataWithTasks(_ tasks: [URLSessionTask], sessionIdentifier: String?) {
    self.lock.lock()
    defer {
      self.lock.unlock()
      self.persistMetadata()
    }

    let activeTaskIds = Set(tasks.map(\.taskIdentifier))
    let reportingSession = sessionIdentifier ?? Self.sessionIdentifier

    for (key, meta) in self.activeMetadata {
      guard (meta.sessionIdentifier ?? Self.sessionIdentifier) == reportingSession else { continue }
      guard let taskId = meta.taskIdentifier else {
        self.activeMetadata.removeValue(forKey: key)
        continue
      }
      guard !activeTaskIds.contains(taskId) else { continue }

      let fm = FileManager.default
      if fm.fileExists(atPath: meta.destinationDirectory.path) {
        let completedEvent = DownloadEvent.completed(
          downloadType: meta.downloadType,
          variantRawValue: meta.variantRawValue,
          destinationDirectory: meta.destinationDirectory,
        )
        DispatchQueue.main.async { self.eventSubject.send(completedEvent) }
      } else {
        let failedEvent = DownloadEvent.failed(
          downloadType: meta.downloadType,
          variantRawValue: meta.variantRawValue,
          error: R2DownloadError.cancelled,
        )
        DispatchQueue.main.async { self.eventSubject.send(failedEvent) }
      }
      self.activeMetadata.removeValue(forKey: key)
      self.activeTasks.removeValue(forKey: key)
    }
  }

  func processDownloadedFile(tempURL: URL, key: String, metadata: DownloadMetadata) {
    let fm = FileManager.default

    self.lock.lock()
    let stillActive = self.activeMetadata[key] != nil
    self.lock.unlock()
    guard stillActive else {
      try? fm.removeItem(at: tempURL)
      return
    }

    if let verifyError = self.verifySHA256(of: tempURL, expected: metadata.expectedSHA256) {
      try? fm.removeItem(at: tempURL)
      self.completeWithFailure(key: key, metadata: metadata, error: verifyError)
      return
    }

    if let extractError = self.extractToDestination(zipURL: tempURL, destinationDir: metadata.destinationDirectory) {
      self.completeWithFailure(key: key, metadata: metadata, error: extractError)
      return
    }

    self.completeWithSuccess(key: key, metadata: metadata)
  }

  private static func volumeIsFull() -> Bool {
    guard let freeBytes = DiskSpace.availableBytes() else { return false }
    return freeBytes < 100_000_000
  }

  private func verifySHA256(of fileURL: URL, expected: String) -> R2DownloadError? {
    do {
      let actualHash = try Self.computeSHA256(of: fileURL)
      guard actualHash == expected.lowercased() else {
        return .sha256Mismatch(expected: expected, actual: actualHash)
      }
      return nil
    } catch {
      return .downloadFailed(error)
    }
  }

  private func extractToDestination(zipURL: URL, destinationDir: URL) -> R2DownloadError? {
    let fm = FileManager.default
    do {
      if fm.fileExists(atPath: destinationDir.path) {
        try fm.removeItem(at: destinationDir)
      }
      try fm.createDirectory(at: destinationDir, withIntermediateDirectories: true)
      try fm.unzipItem(at: zipURL, to: destinationDir)
      try? fm.removeItem(at: zipURL)

      var destURL = destinationDir
      var backupValues = URLResourceValues()
      backupValues.isExcludedFromBackup = true
      try? destURL.setResourceValues(backupValues)

      return nil
    } catch {
      let ranOutOfSpace = Self.volumeIsFull()
      try? fm.removeItem(at: zipURL)
      try? fm.removeItem(at: destinationDir)
      return ranOutOfSpace ? .extractionRanOutOfSpace : .extractionFailed(error)
    }
  }

  private func completeWithSuccess(key: String, metadata: DownloadMetadata) {
    self.lock.lock()
    self.activeMetadata.removeValue(forKey: key)
    self.activeTasks.removeValue(forKey: key)
    self.lastProgress.removeValue(forKey: key)
    self.persistMetadata()
    self.lock.unlock()

    let event = DownloadEvent.completed(
      downloadType: metadata.downloadType,
      variantRawValue: metadata.variantRawValue,
      destinationDirectory: metadata.destinationDirectory,
    )
    DispatchQueue.main.async { self.eventSubject.send(event) }
  }
}
