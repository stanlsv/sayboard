// ModelDownloadService -- Downloads STT model variants on demand via background URLSession

import Combine
import Foundation

import UIKit

// MARK: - ModelDownloadService

@MainActor
final class ModelDownloadService: ObservableObject {

  // MARK: Lifecycle

  init() {
    self.migrateFromHuggingFaceIfNeeded()
    self.verifyExistingModels()
    self.subscribeToDownloadEvents()
  }

  // MARK: Internal

  static let downloadProgressCeiling = 0.95

  static let loadingAnimationStep = 0.001
  static let loadingAnimationIntervalMs = 200

  @Published var variantStates = [ModelVariant: ModelDownloadState]()
  @Published var selectedVariant: ModelVariant = SharedSettings().selectedVariant

  /// Delegate that loads the model into memory after download.
  /// Set by SayboardApp so that performDownload can load the model before setting `.downloaded`.
  weak var modelLoader: (any ModelLoading)?

  /// Cached manifest to avoid re-fetching during a single session.
  var cachedManifest: ModelManifest?

  var eventCancellable: AnyCancellable?
  var enqueueTask: Task<Void, Never>?

  var hasUsableModel: Bool {
    self.isDownloaded(SharedSettings().selectedVariant)
  }

  var activeModelFolderURL: URL? {
    let selected = SharedSettings().selectedVariant
    return self.modelFolderURL(for: selected)
  }

  var downloadedVariants: Set<ModelVariant> {
    Set(ModelVariant.allCases.filter { self.isDownloaded($0) })
  }

  func state(for variant: ModelVariant) -> ModelDownloadState {
    self.variantStates[variant] ?? .notDownloaded
  }

  func isDownloaded(_ variant: ModelVariant) -> Bool {
    self.state(for: variant) == .downloaded
  }

  func selectVariant(_ variant: ModelVariant) {
    SharedSettings().selectedVariant = variant
    self.selectedVariant = variant
    self.syncHasUsableModel()
  }

  /// Returns the on-disk model folder URL for a downloaded variant.
  /// For WhisperKit/Parakeet: the inner folder containing .mlmodelc files.
  /// For Moonshine: the folder containing .ort files.
  func modelFolderURL(for variant: ModelVariant) -> URL? {
    let dir = ModelStorageManager.directory(for: variant)
    guard ModelStorageManager.isDownloaded(variant) else { return nil }

    let fm = FileManager.default
    let targetExtension = variant.engine == .moonshine ? "ort" : "mlmodelc"

    // Check if model files are directly in the variant directory (flat extraction).
    if
      let directContents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil),
      directContents.contains(where: { $0.pathExtension == targetExtension })
    {
      return dir
    }

    // The zip extracts a top-level folder inside the variant directory.
    // Find the first subdirectory that contains the expected model files.
    guard
      let contents = try? fm.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: .skipsHiddenFiles,
      )
    else {
      return nil
    }

    for subdir in contents {
      let isDir = (try? subdir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
      guard isDir else { continue }
      if
        let innerContents = try? fm.contentsOfDirectory(at: subdir, includingPropertiesForKeys: nil),
        innerContents.contains(where: { $0.pathExtension == targetExtension })
      {
        return subdir
      }
    }

    return nil
  }

  func verifyExistingModels() {
    for variant in ModelVariant.allCases {
      switch self.variantStates[variant] {
      case .downloading, .error:
        continue
      case .downloaded, .notDownloaded, .none:
        break
      }

      if ModelStorageManager.isDownloaded(variant) {
        self.variantStates[variant] = .downloaded
      } else {
        self.variantStates[variant] = .notDownloaded
      }
    }
    self.ensureValidSelection()
    self.syncHasUsableModel()
  }

  func ensureValidSelection() {
    let settings = SharedSettings()
    let current = settings.selectedVariant
    guard !self.isDownloaded(current) else {
      self.selectedVariant = current
      return
    }
    if let downloaded = ModelVariant.allCases.first(where: { isDownloaded($0) }) {
      settings.selectedVariant = downloaded
      self.selectedVariant = downloaded
    }
  }

  func startDownload(variant: ModelVariant) {
    guard
      !BackgroundDownloadManager.shared.hasActiveDownload(
        variantRawValue: variant.rawValue,
        downloadType: .stt,
      )
    else { return }

    guard hasEnoughDiskSpace(for: variant) else {
      self.variantStates[variant] = .error(
        message: String(localized: "Not enough storage space. Free up space and try again.")
      )
      return
    }

    let settings = SharedSettings()
    var variants = settings.downloadInProgressVariants
    variants.insert(variant)
    settings.downloadInProgressVariants = variants
    settings.downloadStartedAt = Date()

    UIApplication.shared.isIdleTimerDisabled = true

    self.variantStates[variant] = .downloading(progress: 0)

    self.enqueueTask = Task {
      await self.enqueueDownload(variant: variant)
    }
  }

  func cancelDownload(variant: ModelVariant) {
    self.enqueueTask?.cancel()
    self.enqueueTask = nil

    BackgroundDownloadManager.shared.cancelDownload(
      variantRawValue: variant.rawValue,
      downloadType: .stt,
    )

    // Clean up partially downloaded files
    try? ModelStorageManager.delete(variant)

    self.variantStates[variant] = .notDownloaded
    self.removeVariantFromPersistence(variant)
  }

  func deleteModel(variant: ModelVariant) {
    do {
      try ModelStorageManager.delete(variant)
    } catch {
      // no-op
    }

    self.variantStates[variant] = .notDownloaded

    let settings = SharedSettings()
    if settings.selectedVariant == variant {
      let otherDownloaded = ModelVariant.allCases.first {
        $0 != variant && self.isDownloaded($0)
      }
      if let other = otherDownloaded {
        settings.selectedVariant = other
        self.selectedVariant = other
      }
    }
    self.syncHasUsableModel()
  }

  func dismissError(variant: ModelVariant) {
    self.variantStates[variant] = .notDownloaded
  }

  /// Called on `ScenePhase.active` -- checks if background downloads are still active.
  func resumeInterruptedDownloadIfNeeded() {
    let settings = SharedSettings()
    let interrupted = settings.downloadInProgressVariants
    guard !interrupted.isEmpty else { return }

    for variant in interrupted {
      // If BackgroundDownloadManager still has the task, just keep waiting
      if
        BackgroundDownloadManager.shared.hasActiveDownload(
          variantRawValue: variant.rawValue,
          downloadType: .stt,
        )
      {
        continue
      }
      // Task vanished -- restart
      self.removeVariantFromPersistence(variant)
      self.startDownload(variant: variant)
    }
  }

  /// Called on cold launch -- shows error for downloads interrupted by app termination.
  func checkForInterruptedDownloadOnLaunch() {
    let settings = SharedSettings()
    let interrupted = settings.downloadInProgressVariants
    guard !interrupted.isEmpty else { return }

    let message = String(localized: "Download was interrupted. Tap Retry to continue.")
    for variant in interrupted {
      // Skip variants already verified as downloaded on disk.
      guard self.state(for: variant) != .downloaded else {
        continue
      }
      // Skip if BackgroundDownloadManager still has an active task (download in progress)
      if
        BackgroundDownloadManager.shared.hasActiveDownload(
          variantRawValue: variant.rawValue,
          downloadType: .stt,
        )
      {
        continue
      }
      self.variantStates[variant] = .error(message: message)
    }
    self.clearDownloadPersistence()
    self.syncHasUsableModel()
  }

  func autoSelectIfNeeded(variant: ModelVariant) {
    let settings = SharedSettings()
    if !self.isDownloaded(settings.selectedVariant) {
      settings.selectedVariant = variant
      self.selectedVariant = variant
    }
    self.syncHasUsableModel()
  }

  func syncHasUsableModel() {
    let usable = self.hasUsableModel
    SharedSettings().hasUsableModel = usable
    let selected = SharedSettings().selectedVariant
  }

  func resetToNotDownloaded(variant: ModelVariant) {
    self.variantStates[variant] = .notDownloaded
  }

  func removeVariantFromPersistence(_ variant: ModelVariant) {
    let settings = SharedSettings()
    var variants = settings.downloadInProgressVariants
    variants.remove(variant)
    settings.downloadInProgressVariants = variants
    if variants.isEmpty {
      settings.downloadStartedAt = nil
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }

  // MARK: Private

  private func clearDownloadPersistence() {
    let settings = SharedSettings()
    settings.downloadInProgressVariants = []
    settings.downloadStartedAt = nil
    UIApplication.shared.isIdleTimerDisabled = false
  }

  private func migrateFromHuggingFaceIfNeeded() {
    LegacyModelMigration.runIfNeeded()
  }
}

// MARK: - Helpers

private let diskSpaceSafetyMultiplier = 1.5

private func hasEnoughDiskSpace(for variant: ModelVariant) -> Bool {
  let requiredBytes = Int64(Double(variant.downloadSizeMB) * diskSpaceSafetyMultiplier * 1_000_000)
  do {
    let appSupportURL = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: false,
    )
    let values = try appSupportURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
    guard let available = values.volumeAvailableCapacityForImportantUsage else { return true }
    return available >= requiredBytes
  } catch {
    return true
  }
}
