// BackgroundDownloadManager+Processing -- Download verification, extraction, and session restoration

import Foundation

import ZIPFoundation

extension BackgroundDownloadManager {

  // MARK: Internal

  func reconcileMetadataWithTasks(_ tasks: [URLSessionTask]) {
    self.lock.lock()
    defer {
      self.lock.unlock()
      self.persistMetadata()
    }

    let activeTaskIds = Set(tasks.map(\.taskIdentifier))

    for (key, meta) in self.activeMetadata {
      guard let taskId = meta.taskIdentifier else {
        self.activeMetadata.removeValue(forKey: key)
        continue
      }
      guard !activeTaskIds.contains(taskId) else { continue }

      // Task completed or was cancelled while app was terminated.
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
    }
  }

  func processCompletedDownload(location: URL, key: String, metadata: DownloadMetadata) {
    let fm = FileManager.default
    let tempURL = fm.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("zip")

    do {
      try fm.moveItem(at: location, to: tempURL)
    } catch {
      self.completeWithFailure(key: key, metadata: metadata, error: R2DownloadError.downloadFailed(error))
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

  // MARK: Private

  /// Returns nil on success, or an error on SHA256 mismatch.
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

  /// Returns nil on success, or an error on extraction failure.
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
      try? fm.removeItem(at: zipURL)
      try? fm.removeItem(at: destinationDir)
      return .extractionFailed(error)
    }
  }

  private func completeWithSuccess(key: String, metadata: DownloadMetadata) {
    self.lock.lock()
    self.activeMetadata.removeValue(forKey: key)
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
