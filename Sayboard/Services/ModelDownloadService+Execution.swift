
import Combine
import Foundation

import UIKit

extension ModelDownloadService {

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

  func loadModelAfterDownload(variant: ModelVariant) async -> Bool {
    guard let modelLoader else {
      return false
    }

    guard let modelFolder = self.modelFolderURL(for: variant) else {
      try? ModelStorageManager.delete(variant)
      self.variantStates[variant] = .error(
        message: "Model failed to load. Tap Retry to try again."
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
        message: "Model failed to load. Tap Retry to try again."
      )
      self.removeVariantFromPersistence(variant)
      return false
    }
    return true
  }

  private func handleDownloadEvent(_ event: DownloadEvent) {
    switch event {
    case .progress(_, let variantRawValue, let fraction):
      guard let variant = ModelVariant(rawValue: variantRawValue) else { return }
      let capped = min(fraction, Self.downloadProgressCeiling)
      self.variantStates[variant] = .downloading(progress: capped)

    case .completed(_, let variantRawValue, _):
      guard let variant = ModelVariant(rawValue: variantRawValue) else { return }
      self.enqueueTasks[variant] = nil
      Task {
        let modelReady = await self.loadModelAfterDownload(variant: variant)
        guard modelReady else { return }
        self.variantStates[variant] = .downloaded
        self.removeVariantFromPersistence(variant)
        self.autoSelectIfNeeded(variant: variant)
      }

    case .failed(_, let variantRawValue, let error):
      guard let variant = ModelVariant(rawValue: variantRawValue) else { return }
      self.enqueueTasks[variant] = nil
      self.variantStates[variant] = .error(message: localizedDownloadError(error))
      self.removeVariantFromPersistence(variant)
    }
  }

  private func fetchManifestCached() async throws -> ModelManifest {
    if let cached = self.cachedManifest {
      return cached
    }
    let manifest = try await ManifestFetcher.fetch()
    self.cachedManifest = manifest
    return manifest
  }
}

func localizedDownloadError(_ error: Error) -> LocalizedStringResource {
  if case R2DownloadError.appTooOldForModel = error {
    return "Update Sayboard to use this model."
  }
  if isOutOfSpaceError(error) {
    return "Not enough storage space. Free up space and try again."
  }
  if error is R2DownloadError {
    return "Download failed. Tap Retry to try again."
  }
  if error is ManifestError {
    return "Could not reach model server. Check your connection and try again."
  }
  let nsError = error as NSError
  if nsError.domain == NSURLErrorDomain {
    switch nsError.code {
    case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
      return "No internet connection. Check your network and try again."
    case NSURLErrorTimedOut:
      return "Download timed out. Try again later."
    default:
      return "Network error. Check your connection and try again."
    }
  }
  return "Download failed. Tap Retry to try again."
}

private func isOutOfSpaceError(_ error: Error) -> Bool {
  let posixStorageFull = 28

  func matches(_ error: Error, depth: Int) -> Bool {
    guard depth <= 4 else { return false }

    switch error {
    case R2DownloadError.extractionRanOutOfSpace:
      return true
    case R2DownloadError.extractionFailed(let underlying), R2DownloadError.downloadFailed(let underlying):
      if matches(underlying, depth: depth + 1) { return true }
    default:
      break
    }

    let nsError = error as NSError
    if nsError.domain == NSPOSIXErrorDomain, nsError.code == posixStorageFull { return true }
    if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteOutOfSpaceError { return true }
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
      return matches(underlying, depth: depth + 1)
    }
    return false
  }

  return matches(error, depth: 0)
}
