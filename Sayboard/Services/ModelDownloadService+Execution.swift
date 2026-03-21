// ModelDownloadService+Execution -- Download event handling, model loading, and error helpers

import Combine
import Foundation

import UIKit

// MARK: - Event Subscription

extension ModelDownloadService {

  // MARK: Internal

  func subscribeToDownloadEvents() {
    self.eventCancellable = BackgroundDownloadManager.shared.eventSubject
      .filter { event in
        switch event {
        case .progress(let type, _, _): type == .stt
        case .completed(let type, _, _): type == .stt
        case .failed(let type, _, _): type == .stt
        }
      }
      .receive(on: DispatchQueue.main)
      .sink { [weak self] event in
        self?.handleDownloadEvent(event)
      }
  }

  /// Fetches manifest and enqueues the download via BackgroundDownloadManager.
  func enqueueDownload(variant: ModelVariant) async {
    do {
      let manifest = try await self.fetchManifestCached()
      guard let entry = manifest.entry(for: variant) else {
        throw R2DownloadError.manifestMissingVariant(variant.rawValue)
      }

      try ModelStorageManager.ensureRootExists()
      let destDir = ModelStorageManager.directory(for: variant)

      let metadata = DownloadMetadata(
        downloadType: .stt,
        variantRawValue: variant.rawValue,
        expectedSHA256: entry.sha256,
        sourceURL: entry.url,
        destinationDirectory: destDir,
        sizeBytes: entry.sizeBytes,
      )

      BackgroundDownloadManager.shared.enqueueDownload(metadata: metadata)
    } catch {
      self.variantStates[variant] = .error(message: localizedDownloadError(error))
      self.removeVariantFromPersistence(variant)
    }
  }

  /// Runs model loading phase (95%-100%) with animated progress. Returns `true` on success.
  func loadModelAfterDownload(variant: ModelVariant) async -> Bool {
    guard let modelLoader else {
      return false
    }

    guard let modelFolder = self.modelFolderURL(for: variant) else {
      try? ModelStorageManager.delete(variant)
      self.variantStates[variant] = .error(
        message: String(localized: "Model failed to load. Tap Retry to try again.")
      )
      self.removeVariantFromPersistence(variant)
      return false
    }

    let ceiling = Self.downloadProgressCeiling
    self.variantStates[variant] = .downloading(progress: ceiling)

    let animationTask = Task {
      var current = ceiling
      while !Task.isCancelled, current < 0.99 {
        try? await Task.sleep(for: .milliseconds(Self.loadingAnimationIntervalMs))
        guard !Task.isCancelled else { break }
        current = min(current + Self.loadingAnimationStep, 0.99)
        self.variantStates[variant] = .downloading(progress: current)
      }
    }

    let loaded = await modelLoader.loadModel(variant: variant, from: modelFolder)
    animationTask.cancel()

    if !loaded {
      try? ModelStorageManager.delete(variant)
      self.variantStates[variant] = .error(
        message: String(localized: "Model failed to load. Tap Retry to try again.")
      )
      self.removeVariantFromPersistence(variant)
      return false
    }
    return true
  }

  // MARK: Private

  private func handleDownloadEvent(_ event: DownloadEvent) {
    switch event {
    case .progress(_, let variantRawValue, let fraction):
      guard let variant = ModelVariant(rawValue: variantRawValue) else { return }
      let capped = min(fraction, Self.downloadProgressCeiling)
      self.variantStates[variant] = .downloading(progress: capped)

    case .completed(_, let variantRawValue, _):
      guard let variant = ModelVariant(rawValue: variantRawValue) else { return }
      Task {
        let modelReady = await self.loadModelAfterDownload(variant: variant)
        guard modelReady else { return }
        self.variantStates[variant] = .downloaded
        self.removeVariantFromPersistence(variant)
        self.autoSelectIfNeeded(variant: variant)
      }

    case .failed(_, let variantRawValue, let error):
      guard let variant = ModelVariant(rawValue: variantRawValue) else { return }
      self.variantStates[variant] = .error(message: localizedDownloadError(error))
      self.removeVariantFromPersistence(variant)
    }
  }

  /// Fetches the manifest from R2, caching in memory for the duration of the session.
  private func fetchManifestCached() async throws -> ModelManifest {
    if let cached = self.cachedManifest {
      return cached
    }
    let manifest = try await ManifestFetcher.fetch()
    self.cachedManifest = manifest
    return manifest
  }
}

// MARK: - Helpers

func localizedDownloadError(_ error: Error) -> String {
  if error is R2DownloadError {
    return String(localized: "Download failed. Tap Retry to try again.")
  }
  if error is ManifestError {
    return String(localized: "Could not reach model server. Check your connection and try again.")
  }
  let nsError = error as NSError
  if nsError.domain == NSURLErrorDomain {
    switch nsError.code {
    case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
      return String(localized: "No internet connection. Check your network and try again.")
    case NSURLErrorTimedOut:
      return String(localized: "Download timed out. Try again later.")
    default:
      return String(localized: "Network error. Check your connection and try again.")
    }
  }
  let posixStorageFull: Int32 = 28 // ENOSPC
  if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(posixStorageFull) {
    return String(localized: "Not enough storage space. Free up space and try again.")
  }
  if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteOutOfSpaceError {
    return String(localized: "Not enough storage space. Free up space and try again.")
  }
  return String(localized: "Download failed. Tap Retry to try again.")
}
