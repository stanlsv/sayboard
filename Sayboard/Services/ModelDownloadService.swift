
import Combine
import Foundation

import UIKit

@MainActor
final class ModelDownloadService: ObservableObject {

  init() {
    self.migrateFromHuggingFaceIfNeeded()
    self.verifyExistingModels()
    self.subscribeToDownloadEvents()
  }

  static let downloadProgressCeiling = 0.95

  static let loadingAnimationStep = 0.001
  static let loadingAnimationIntervalMs = 200

  @Published var variantStates = [ModelVariant: ModelDownloadState]()
  @Published var selectedVariant: ModelVariant = SharedSettings().selectedVariant

  weak var modelLoader: (any ModelLoading)?

  var cachedManifest: ModelManifest?

  var eventCancellable: AnyCancellable?
  var enqueueTasks = [ModelVariant: Task<Void, Never>]()

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

  func modelFolderURL(for variant: ModelVariant) -> URL? {
    let dir = ModelStorageManager.directory(for: variant)
    guard ModelStorageManager.isDownloaded(variant) else { return nil }

    let fm = FileManager.default
    let targetExtension = variant.engine == .moonshine ? "ort" : "mlmodelc"

    if
      let directContents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil),
      directContents.contains(where: { $0.pathExtension == targetExtension })
    {
      return dir
    }

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
    if current == .parakeetV3, settings.parakeetV3NeedsRedownload {
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
        message: "Not enough storage space. Free up space and try again."
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

    self.enqueueTasks[variant] = Task {
      await self.enqueueDownload(variant: variant)
    }
  }

  func cancelDownload(variant: ModelVariant) {
    self.enqueueTasks[variant]?.cancel()
    self.enqueueTasks[variant] = nil

    BackgroundDownloadManager.shared.cancelDownload(
      variantRawValue: variant.rawValue,
      downloadType: .stt,
    )

    try? ModelStorageManager.delete(variant)

    self.variantStates[variant] = .notDownloaded
    self.removeVariantFromPersistence(variant)
  }

  func deleteModel(variant: ModelVariant) {
    do {
      try ModelStorageManager.delete(variant)
    } catch { }

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

  func resumeInterruptedDownloadIfNeeded() {
    let settings = SharedSettings()
    let interrupted = settings.downloadInProgressVariants
    guard !interrupted.isEmpty else { return }

    for variant in interrupted {
      if
        BackgroundDownloadManager.shared.hasActiveDownload(
          variantRawValue: variant.rawValue,
          downloadType: .stt,
        )
      {
        continue
      }
      self.removeVariantFromPersistence(variant)
      self.startDownload(variant: variant)
    }
  }

  func checkForInterruptedDownloadOnLaunch() {
    let settings = SharedSettings()
    let interrupted = settings.downloadInProgressVariants
    guard !interrupted.isEmpty else { return }

    let message: LocalizedStringResource = "Download was interrupted. Tap Retry to continue."
    for variant in interrupted {
      guard self.state(for: variant) != .downloaded else {
        continue
      }
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
    let _ = SharedSettings().selectedVariant
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

private let diskSpaceSafetyMultiplier = 2.6

private func hasEnoughDiskSpace(for variant: ModelVariant) -> Bool {
  let requiredBytes = Int64(Double(variant.downloadSizeMB.megabytesInBytes) * diskSpaceSafetyMultiplier)
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
